class AppBuildInfo {
  static const String buildName =
      String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: 'dev');
  static const String buildNumber =
      String.fromEnvironment('FLUTTER_BUILD_NUMBER', defaultValue: '0');

  static String displayVersion() => 'v$buildName+$buildNumber';
}
