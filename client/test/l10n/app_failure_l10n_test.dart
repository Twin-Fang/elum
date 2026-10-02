import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/l10n/app_localizations_ko.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppFailure.hint` 는 번역 문구를 쓰되, **서버가 준 문구가 이기는 규칙(#347)은 그대로**다.
class _FakeL10n extends AppLocalizationsKo {
  @override
  String get failureHintOffline => 'OFFLINE-HINT';
}

void main() {
  tearDown(setAppL10nForTest);

  test('hint 는 앱 언어의 문구다', () {
    setAppL10nForTest(_FakeL10n());
    expect(const AppFailure(fault: NetworkFault.offline).hint, 'OFFLINE-HINT');
  });

  test('기본(ko)은 옛 문구와 같다 — 세 가지 모두 손으로 쓴 값으로 단언', () {
    expect(
      const AppFailure(fault: NetworkFault.offline).hint,
      '인터넷 연결을 확인해주세요',
    );
    expect(
      const AppFailure(fault: NetworkFault.timeout).hint,
      '연결이 느려요. 잠시 후 다시 해주세요',
    );
    expect(
      const AppFailure(fault: NetworkFault.badCertificate).hint,
      '안전하지 않은 연결이에요. 다른 망에서 해주세요',
    );
    expect(const AppFailure(fault: NetworkFault.none).hint, isNull);
  });

  test('서버 문구가 있으면 서버 문구가 이긴다 — 언어와 무관', () {
    setAppL10nForTest(_FakeL10n());
    const failure = AppFailure(
      fault: NetworkFault.none,
      server: ServerError(
        code: ServerErrorCode.unknown,
        message: '서버가 준 문구예요',
        statusCode: 403,
      ),
    );
    expect(failure.bodyOr('화면 기본 문구'), '서버가 준 문구예요');
    expect(failure.messageOr('화면 기본 문구'), '서버가 준 문구예요');
  });

  test('안내를 붙일 때는 화면 문구의 첫 문장만 쓴다 — 일본어 `。` 도 문장 끝이다', () {
    setAppL10nForTest(_FakeL10n());
    const failure = AppFailure(fault: NetworkFault.offline);
    expect(
      failure.bodyOr('일과를 불러오지 못했어요. 다시 해주세요'),
      '일과를 불러오지 못했어요 · OFFLINE-HINT',
    );
    expect(
      failure.bodyOr('読み込めませんでした。もう一度お試しください'),
      '読み込めませんでした · OFFLINE-HINT',
    );
  });
}
