defmodule Cldr.AcceptLanguage do
  @moduledoc """
  Tokenizer and parser for HTTP `Accept-Language` header values as defined in
  [rfc2616](https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4).

  The Accept-Language request-header field is similar to Accept, but restricts
  the set of natural languages that are preferred as a response to the request.
  Language tags function are provided in `Cldr.LanguageTag`.

  The format of an `Accept-Language` header is as follows in `ABNF` format:

         Accept-Language = "Accept-Language" ":"
                           1#( language-range [ ";" "q" "=" qvalue ] )
         language-range  = ( ( 1*8ALPHA *( "-" 1*8ALPHA ) ) | "*" )

  Each language-range MAY be given an associated quality value which represents an
  estimate of the user's preference for the languages specified by that range. The
  quality value defaults to "q=1". For example,

         Accept-Language: da, en-gb;q=0.8, en;q=0.7

  would mean: "I prefer Danish, but will accept British English and other types of English."
  """
  alias Cldr.Locale

  @default_quality 1.0
  @low_quality 0.2

  @doc """
  Splits the language ranges for an `Accept-Language` header
  value into tuples `{quality, language}`.

  ## Example

      iex> Cldr.AcceptLanguage.tokenize "da,zh-TW;q=0.3"
      [{1.0, "da"}, {0.3, "zh-tw"}]

  """
  @language_separator ","
  def tokenize(accept_language) do
    accept_language
    |> String.downcase
    |> remove_whitespace
    |> String.split(@language_separator)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&String.starts_with?(&1, "*"))
    |> Enum.map(&token_tuple/1)
  end

  @quality_separator ";q="
  defp token_tuple(language) do
    case String.split(language, @quality_separator) do
      [language, quality] ->
        {parse_quality(quality), language}
      [language] ->
        {@default_quality, language}
      [language | _rest] ->
        {@low_quality, language}
    end
  end

  @doc """
  Parses an `Accept-Language` header value in its string
  or tokenized form to return a tuple of the form
  `{:ok, [{quality, %Cldr.LanguageTag{}}, ...]}` sorted by quality.

  If not valid language tags are found, the tuple `{:error, reason}`
  is returned.

  If at least one valid language tag is found but errors are also
  detected on one more more tags, an `{ok, list}` tuple is returned
  wuth an error tuple for each invalid tag added at the end of the list.

  ## Example

      iex> Cldr.AcceptLanguage.parse "da,zh-TW;q=0.3"
      {:ok,
        [{1.0,
          %Cldr.LanguageTag{canonical_locale_name: "da-Latn-DK",
           cldr_locale_name: "da", extensions: %{}, language: "da",
           locale: %{}, private_use: [], rbnf_locale_name: "da",
           territory: "DK", requested_locale_name: "da", script: "Latn",
           transform: %{}, variant: nil}},
         {0.3,
          %Cldr.LanguageTag{canonical_locale_name: "zh-Hant-TW",
           cldr_locale_name: "zh-Hant", extensions: %{}, language: "zh",
           locale: %{}, private_use: [], rbnf_locale_name: "zh-Hant",
           territory: "TW", requested_locale_name: "zh-TW", script: "Hant",
           transform: %{}, variant: nil}}]}


      iex> Cldr.AcceptLanguage.parse "X"
      {:error,
       {Cldr.AcceptLanguageError,
        "Could not parse language tag.  Error was detected at 'x'"}}

      iex> Cldr.AcceptLanguage.parse "da,zh-TW;q=0.3,X"
      {:ok,
        [{1.0,
          %Cldr.LanguageTag{canonical_locale_name: "da-Latn-DK",
           cldr_locale_name: "da", extensions: %{}, language: "da",
           locale: %{}, private_use: [], rbnf_locale_name: "da",
           territory: "DK", requested_locale_name: "da", script: "Latn",
           transform: %{}, variant: nil}},
         {0.3,
          %Cldr.LanguageTag{canonical_locale_name: "zh-Hant-TW",
           cldr_locale_name: "zh-Hant", extensions: %{}, language: "zh",
           locale: %{}, private_use: [], rbnf_locale_name: "zh-Hant",
           territory: "TW", requested_locale_name: "zh-TW", script: "Hant",
           transform: %{}, variant: nil}},
         {:error,
          {Cldr.InvalidLanguageTag,
           "Could not parse language tag.  Error was detected at 'x'"},
          "x"}]}

  """
  def parse(tokens) when is_list(tokens) do
    accept_language =
      tokens
      |> parse_language_tags
      |> sort_by_quality

    case accept_language do
      [{:error, reason, language_tag}] ->
        {:error, accept_language_error(reason, language_tag)}
      _ ->
        {:ok, accept_language}
    end
  end

  def parse(string) when is_binary(string) do
    string
    |> tokenize
    |> parse
  end

  @doc """
  Parses an `Accept-Language` header value in its string
  or tokenized form to produce a list of tuples of the form
  `[{quality, %Cldr.LanguageTag{}}, ...]` sorted by quality
  in decending order.

  If no valid language tags are found, an exception is raised.

  If at least one valid language tag is found but errors are also
  detected on one more more tags, an `{ok, list}` tuple is returned
  wuth an error tuple for each invalid tag added at the end of the list.

  ## Example

      iex> Cldr.AcceptLanguage.parse! "da,zh-TW;q=0.3"
      [{1.0,
         %Cldr.LanguageTag{canonical_locale_name: "da-Latn-DK",
          cldr_locale_name: "da", extensions: %{}, language: "da",
          locale: %{}, private_use: [], rbnf_locale_name: "da", territory: "DK",
          requested_locale_name: "da", script: "Latn", transform: %{},
          variant: nil}},
        {0.3,
         %Cldr.LanguageTag{canonical_locale_name: "zh-Hant-TW",
          cldr_locale_name: "zh-Hant", extensions: %{}, language: "zh",
          locale: %{}, private_use: [], rbnf_locale_name: "zh-Hant",
          territory: "TW", requested_locale_name: "zh-TW", script: "Hant",
          transform: %{}, variant: nil}}]


      Cldr.AcceptLanguage.parse! "X"
      ** (Cldr.AcceptLanguageError) Could not parse language tag.  Error was detected at 'x'
          (ex_cldr) lib/cldr/accept_language.ex:168: Cldr.AcceptLanguage.parse!/1

      iex> Cldr.AcceptLanguage.parse! "da,zh-TW;q=0.3,X"
      [{1.0,
         %Cldr.LanguageTag{canonical_locale_name: "da-Latn-DK",
          cldr_locale_name: "da", extensions: %{}, language: "da",
          locale: %{}, private_use: [], rbnf_locale_name: "da", territory: "DK",
          requested_locale_name: "da", script: "Latn", transform: %{},
          variant: nil}},
        {0.3,
         %Cldr.LanguageTag{canonical_locale_name: "zh-Hant-TW",
          cldr_locale_name: "zh-Hant", extensions: %{}, language: "zh",
          locale: %{}, private_use: [], rbnf_locale_name: "zh-Hant",
          territory: "TW", requested_locale_name: "zh-TW", script: "Hant",
          transform: %{}, variant: nil}},
        {:error,
         {Cldr.InvalidLanguageTag,
          "Could not parse language tag.  Error was detected at 'x'"}, "x"}]

  """
  def parse!(accept_language) do
    case parse(accept_language) do
      {:ok, parse_result} -> parse_result
      {:error, {exception, reason}} -> raise exception, reason
    end
  end

  @doc """
  Filters the returned results of `parse/1` to return
  only the error tuples.

  ## Example

      iex> Cldr.AcceptLanguage.parse!("da,zh-TW;q=0.3,X") |> Cldr.AcceptLanguage.errors
      [{:error,
        {Cldr.InvalidLanguageTag,
         "Could not parse language tag.  Error was detected at 'x'"}, "x"}]

  """
  def errors(parse_result) when is_list(parse_result) do
    Enum.filter(parse_result, fn
      {:error, _, _} -> true
      _ -> false
    end)
  end

  defp parse_quality(quality_string) do
    case Float.parse(quality_string) do
      :error -> @low_quality
      {quality, _} -> quality
    end
  end

  defp parse_language_tags(tokens) do
    Enum.map(tokens, fn {quality, language_tag} ->
      case Locale.canonical_language_tag(language_tag) do
        {:ok, tag} ->
          {quality, tag}
        {:error, reason} ->
          {:error, reason, language_tag}
      end
    end)
  end

  defp remove_whitespace(accept_language) do
    String.replace(accept_language, " ", "")
  end

  defp sort_by_quality(tokens) do
    Enum.sort(tokens, fn
      {:error, _, _}, {_quality_2, _} -> false
      {_quality_2, _}, {:error, _, _} -> true
      {quality_1, _}, {quality_2, _} -> quality_1 > quality_2
    end)
  end

  defp accept_language_error({_exception, reason}, _language_tag) do
    {Cldr.AcceptLanguageError, reason}
  end
end