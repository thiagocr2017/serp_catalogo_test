/// Returns an active search term only after the user enters three characters.
/// Falling below the threshold clears the filter and restores all results.
String effectiveSearchQuery(String value, {int minimumCharacters = 3}) {
  final query = value.trim();
  return query.runes.length >= minimumCharacters ? query : '';
}
