class AppConfig {
  const AppConfig._();

  static const appName = 'Wood And Panel';
  static const wordpressBaseUrl = String.fromEnvironment(
    'WORDPRESS_BASE_URL',
    defaultValue: 'https://www.woodandpanel.com',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'APP_API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );
  static const defaultPageSize = 12;
  static const articleDeepLinkHost = 'woodandpanel://article';
}
