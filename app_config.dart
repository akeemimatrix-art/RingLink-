class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT');

  static const appName = 'RingLink';
  static const defaultRadiusMeters = 1500.0;
}
