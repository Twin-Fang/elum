import 'package:elum/features/profile/application/invite_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

/// 링크로 받은 초대 코드를 알맞은 때까지 들고 있는 우편함 (#365).
void main() {
  late DateTime clock;
  late InviteInbox inbox;

  setUp(() {
    clock = DateTime(2026, 10, 1, 12);
    inbox = InviteInbox(now: () => clock);
  });

  test('받은 코드는 한 번만 나온다 — 같은 코드를 두 번 보내면 두 번째는 409 다', () {
    inbox.receive('A7K3M9');

    expect(inbox.hasPending, isTrue);
    expect(inbox.take()?.code, 'A7K3M9');
    expect(inbox.take(), isNull);
    expect(inbox.hasPending, isFalse);
  });

  test('아무것도 받지 않았으면 비어 있다', () {
    expect(inbox.hasPending, isFalse);
    expect(inbox.take(), isNull);
  });

  test('코드를 못 쓰는 링크도 받은 것으로 둔다 — 화면이 에러 안내를 띄우려면 필요하다', () {
    inbox.receive(null);

    expect(inbox.hasPending, isTrue);
    final p = inbox.take();
    expect(p, isNotNull);
    expect(p!.code, isNull);
  });

  test('나중에 받은 링크가 앞의 것을 대신한다 — 다시 만들면 앞 코드는 서버에서 폐기된다', () {
    inbox.receive('A7K3M9');
    inbox.receive('B2C4D6');

    expect(inbox.take()?.code, 'B2C4D6');
    expect(inbox.take(), isNull);
  });

  group('10분이 지나면 버린다', () {
    test('9분 59초까지는 남아 있다', () {
      inbox.receive('A7K3M9');
      clock = clock.add(const Duration(minutes: 9, seconds: 59));

      expect(inbox.hasPending, isTrue);
      expect(inbox.take()?.code, 'A7K3M9');
    });

    test('10분이 되면 없다 — 만료된 코드를 채워 서버에서 되돌려 받게 하지 않는다', () {
      inbox.receive('A7K3M9');
      clock = clock.add(const Duration(minutes: 10));

      expect(inbox.hasPending, isFalse);
      expect(inbox.take(), isNull);
    });

    test('만료 판단은 받은 시각 기준이다 — 나중 링크는 새로 센다', () {
      inbox.receive('A7K3M9');
      clock = clock.add(const Duration(minutes: 9));
      inbox.receive('B2C4D6');
      clock = clock.add(const Duration(minutes: 9));

      expect(inbox.take()?.code, 'B2C4D6');
    });
  });

  test('받으면 듣고 있는 화면에 알린다 — 입력 화면이 이미 열려 있을 때 채우려고', () {
    var notified = 0;
    inbox.addListener(() => notified++);

    inbox.receive('A7K3M9');
    expect(notified, 1);

    // 꺼내거나 비우는 것은 알리지 않는다 — 반응할 곳이 없다
    inbox.take();
    inbox.receive('B2C4D6');
    inbox.clear();
    expect(notified, 2);
    expect(inbox.hasPending, isFalse);
  });
}
