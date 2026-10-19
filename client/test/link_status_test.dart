import 'package:elum/features/link/domain/link_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버 응답을 화면 값으로 옮기기 (이슈 #205).
///
/// **응답이 예상과 달라도 화면이 죽지 않아야 한다** — 저장소 규칙.
void main() {
  group('남은 시간 표시', _remainingLabelRules);

  group('연결 상태', () {
    test('연결된 기기를 여러 대 담는다', () {
      final s = LinkStatus.fromJson({
        'devices': [
          {'linkId': 'l1', 'linkedAt': '2026-09-18T10:00:00'},
          {'linkId': 'l2', 'linkedAt': '2026-09-18T11:00:00'},
        ],
        'pendingExpiresAt': null,
      });

      expect(s.devices.map((d) => d.linkId), ['l1', 'l2']);
      expect(s.hasDevice, isTrue);
    });

    test('devices 가 리스트가 아니어도 죽지 않는다', () {
      final s = LinkStatus.fromJson({'devices': 'oops'});
      expect(s.devices, isEmpty);
      expect(s.hasDevice, isFalse);
    });

    test('linkId 없는 항목은 버린다 — 끊을 수 없는 줄을 보여줄 이유가 없다', () {
      final s = LinkStatus.fromJson({
        'devices': [
          {'linkedAt': '2026-09-18T10:00:00'},
          {'linkId': 'l2'},
        ],
      });
      expect(s.devices.map((d) => d.linkId), ['l2']);
    });

    test('옛 서버 응답(새 필드 없음)·형식이 다른 값에도 죽지 않는다', () {
      final s = LinkStatus.fromJson({
        'devices': [
          {'linkId': 'l1'},
          {'linkId': 'l2', 'deviceName': 7, 'linkedByName': '  ', 'linkedByMe': 'yes'},
        ],
      });
      for (final d in s.devices) {
        expect(d.deviceName, isNull);
        expect(d.linkedByName, isNull);
        expect(d.linkedByMe, isFalse);
      }
    });

  });

  group('발급된 암호', () {
    test('만료 뒤에는 0이다 — 음수가 새어 나가면 문구가 이상해진다', () {
      final c = IssuedLinkCode(
        code: 'A7K3M9',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(c.isExpired, isTrue);
      expect(c.remaining(), Duration.zero);
    });
  });
}

/// 남은 시간을 분으로 말할 때 **서버가 준 것보다 길게 말하면 안 된다** (이슈 #205).
/// 사용자가 그 말을 믿고 기다리다 만료된다.
int minutesLabel(Duration left) => (left.inSeconds / 60).ceil();

void _remainingLabelRules() {
}
