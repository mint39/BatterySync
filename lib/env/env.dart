import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'KEY_Android', obfuscate: true)
  static String keyAndroid = _Env.keyAndroid;

  @EnviedField(varName: 'KEY_iOS', obfuscate: true)
  static String keyIOS = _Env.keyIOS;

  @EnviedField(varName: 'GEMINI', obfuscate: true)
  static String Gemini = _Env.Gemini;
}

