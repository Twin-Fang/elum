import 'package:elum/core/config/app_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// 설정값이 잘못돼도 앱은 떠야 한다.
/// .env 하나 때문에 데모가 막히면 안 되므로 fallback을 검증한다.
void main() {
  // 빈 .env 상태를 재현한다. isOptional을 켜야 빈 문자열에서 예외가 나지 않는다.
  setUp(() => dotenv.loadFromString(envString: '', isOptional: true));

  group('AppConfig 기본값', () {
    test('.env가 비어도 서버 URL 기본값이 나온다', () {
      expect(AppConfig.apiBaseUrl, 'https://api.elum.chuseok22.com');
    });

  });

  group('AppConfig 값 읽기', () {

    test('숫자가 아닌 값이 와도 죽지 않고 기본값을 쓴다', () {
      dotenv.loadFromString(envString: 'ELUM_DLP_MIN_DELAY_MS=빠르게');
      expect(AppConfig.dlpMinDelay, const Duration(milliseconds: 1500));
    });

  });
}
