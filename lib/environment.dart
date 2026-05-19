late Environment _env;

Environment get env => _env;

class Environment {
  final String defaultAppLanguageCode;
  final String plataformType;

  Environment._init({
    required this.defaultAppLanguageCode,
    required this.plataformType,
  });

  static void init({
    String defaultAppLanguageCode = 'en',
    required String plataformType,
  }) {
    _env = Environment._init(
      plataformType: plataformType,
      defaultAppLanguageCode: defaultAppLanguageCode,
    );
  }
}
