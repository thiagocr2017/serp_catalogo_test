class AppConfiguration {
  const AppConfiguration({
    required this.supabaseUrl,
    required this.supabaseKey,
  });

  factory AppConfiguration.local() {
    return const AppConfiguration(
      supabaseUrl: String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'http://127.0.0.1:54321',
      ),
      supabaseKey: String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
      ),
    );
  }

  final String supabaseUrl;
  final String supabaseKey;
}
