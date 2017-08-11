defmodule Cldr.DateTime do
  alias Cldr.DateTime.Formatter

  @doc """
  Formats a datetime according to a format string
  as defined in CLDR and described in [TR35](http://unicode.org/reports/tr35/tr35-dates.html)

  * `datetime` is a `%DateTime{}` `or %NaiveDateTime{}`struct or any map that contains the keys
  `year`, `month`, `day`, `calendar`. `hour`, `minute` and `second` with optional `microsecond`.

  * `options` is a keyword list of options for formatting.  The valid options are:
    * `format:` `:short` | `:medium` | `:long` | `:full`. any of the keys returned by `Cldr.DateTime.available_format_names` or a format string.  The default is `:medium`
    * `locale:` any locale returned by `Cldr.known_locales()`.  The default is `Cldr.get_current_locale()`
    * `number_system:` a number system into which the formatted date digits should be transliterated

  ## Examples

  """
  @format_types [:short, :medium, :long, :full]

  def to_string(date, options \\ [])
  def to_string(%{year: _year, month: _month, day: _day, hour: _hour, minute: _minute, second: _second,
      calendar: calendar} = datetime, options) do
    default_options = [format: :medium, locale: Cldr.get_current_locale()]
    options = Keyword.merge(default_options, options)

    with {:ok, locale} <- Cldr.valid_locale?(options[:locale]),
         {:ok, format_string} <- format_string_from_format(options[:format], locale, calendar),
         {:ok, formatted} <- Formatter.format(datetime, format_string, locale, options)
    do
      {:ok, formatted}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def to_string!(date, options \\ [])
  def to_string!(%{year: _year, month: _month, day: _day, hour: _hour, minute: _minute, second: _second,
      calendar: _calendar} = datetime, options) do
    case to_string(datetime, options) do
      {:ok, string} -> string
      {:error, {exception, message}} -> raise exception, message
    end
  end

  # Standard format
  defp format_string_from_format(format, locale, calendar) when format in @format_types do
    cldr_calendar = Formatter.type_from_calendar(calendar)

    format_string =
      locale
      |> Cldr.get_locale
      |> Map.get(:dates)
      |> get_in([:calendars, cldr_calendar, :date_time_formats, format])
    {:ok, format_string}
  end

  # Look up for the format in :available_formats
  defp format_string_from_format(format, locale, calendar) when is_atom(format) do
    cldr_calendar = Formatter.type_from_calendar(calendar)

    format_string =
      locale
      |> Cldr.get_locale
      |> Map.get(:dates)
      |> get_in([:calendars, cldr_calendar, :date_time_formats, :available_formats, format])

    if format_string do
      {:ok, format_string}
    else
      {:error, {Cldr.InvalidDateTimeFormatType, "Invalid datetime format type. " <>
                "The valid types are #{inspect @format_types}."}}
    end
  end

  # Format with a number system
  defp format_string_from_format(%{number_system: number_system, format: format}, locale, calendar) do
    {:ok, format_string} = format_string_from_format(format, locale, calendar)
    {:ok, %{number_system: number_system, format: format_string}}
  end

  # Straight up format string
  defp format_string_from_format(format_string, _locale, _calendar) when is_binary(format_string) do
    {:ok, format_string}
  end
end