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

    test('.env가 비어도 타임아웃 기본값이 나온다', () {
      expect(AppConfig.connectTimeout, const Duration(milliseconds: 10000));
      expect(AppConfig.receiveTimeout, const Duration(milliseconds: 60000));
    });

    test('DLP 최소 연출 시간 기본값이 나온다', () {
      expect(AppConfig.dlpMinDelay, const Duration(milliseconds: 1500));
    });
  });

  group('AppConfig 값 읽기', () {
    test('.env 값이 있으면 그 값을 쓴다', () {
      dotenv.loadFromString(envString: 'ELUM_API_BASE_URL=http://localhost:8080');
      expect(AppConfig.apiBaseUrl, 'http://localhost:8080');
    });

    test('빈 문자열은 미설정으로 보고 기본값을 쓴다', () {
      dotenv.loadFromString(envString: 'ELUM_API_BASE_URL=');
      expect(AppConfig.apiBaseUrl, 'https://api.elum.chuseok22.com');
    });

    test('숫자가 아닌 값이 와도 죽지 않고 기본값을 쓴다', () {
      dotenv.loadFromString(envString: 'ELUM_DLP_MIN_DELAY_MS=빠르게');
      expect(AppConfig.dlpMinDelay, const Duration(milliseconds: 1500));
    });

    test('개발자 도구는 기본이 꺼짐이다', () {
      // .env를 안 만든 사람에게 개발자 도구가 뜨면 안 된다
      expect(AppConfig.showDevTools, isFalse);

      dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
      expect(AppConfig.showDevTools, isTrue);
    });

    test('bool은 여러 표기를 받아들인다', () {
      dotenv.loadFromString(envString: 'ELUM_USE_MOCK=false');
      expect(AppConfig.useMock, isFalse);

      dotenv.loadFromString(envString: 'ELUM_USE_MOCK=0');
      expect(AppConfig.useMock, isFalse);

      dotenv.loadFromString(envString: 'ELUM_USE_MOCK=yes');
      expect(AppConfig.useMock, isTrue);
    });
  });
}
