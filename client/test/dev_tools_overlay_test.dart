import 'package:elum/core/dev/dev_tools_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// 오버레이는 개발용이므로 **꺼졌을 때 흔적이 남지 않는 것**이 가장 중요하다.
/// 플래그를 끄고 배포했는데 버튼이 보이면 사용자에게 그대로 노출된다. (이슈 #13)
void main() {
  /// **실제 배치를 그대로 재현한다.**
  ///
  /// 오버레이는 `app.dart`에서 `MaterialApp.router`의 `builder`에 놓인다.
  /// 그 위치는 라우터 Navigator "바깥"이라 상위에 Navigator가 없다.
  ///
  /// 처음에는 `MaterialApp(home: DevToolsOverlay(...))`로 테스트했는데,
  /// 그러면 오버레이가 Navigator "안쪽"이 되어 통과해버린다. 실기기에서는
  /// "context does not include a Navigator"로 터졌다. 배치가 다르면
  /// 테스트가 아무것도 지켜주지 못한다.
  Widget buildSubject() {
    return ProviderScope(
      overrides: [testStorageOverride()],
      child: MaterialApp(
        home: const Scaffold(body: Text('앱 화면')),
        builder: (context, child) =>
            DevToolsOverlay(child: child ?? const SizedBox.shrink()),
      ),
    );
  }

  testWidgets('플래그가 꺼져 있으면 버튼이 보이지 않는다', (tester) async {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=false');

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('앱 화면'), findsOneWidget);
    expect(find.byIcon(Icons.bug_report), findsNothing);
  });

  testWidgets('설정이 아예 없어도 기본은 꺼짐이다', (tester) async {
    // .env를 안 만든 사람에게 개발자 도구가 뜨면 안 된다
    dotenv.loadFromString(envString: '', isOptional: true);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bug_report), findsNothing);
  });

  testWidgets('플래그가 켜져 있으면 버튼이 보인다', (tester) async {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bug_report), findsOneWidget);
    // 아래 화면을 가리지 않는다
    expect(find.text('앱 화면'), findsOneWidget);
  });

  testWidgets('버튼을 누르면 패널이 열린다', (tester) async {
    // 실기기에서 이 지점이 터졌다 — 오버레이가 라우터 Navigator 바깥이라
    // showModalBottomSheet가 Navigator를 못 찾았다.
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bug_report));
    await tester.pumpAndSettle();

    // 예외가 삼켜지지 않았는지 명시적으로 확인한다
    expect(tester.takeException(), isNull);

    expect(find.text('개발자 도구'), findsOneWidget);
    expect(find.text('온보딩 초기화'), findsOneWidget);
    expect(find.text('로그 보기'), findsOneWidget);
  });

  // 각 하위 화면은 Navigator 없이 시트 안에서 전환된다.
  // 하나라도 Navigator를 쓰면 실기기에서 터지므로 개별로 확인한다.
  for (final (label, expected) in const [
    ('로그 보기', '아직 로그가 없어요'),
    ('현재 상태', '저장값'),
    ('화면 이동', '보호자 홈'),
    ('온보딩 초기화', '초기화'),
  ]) {
    testWidgets('$label 화면이 예외 없이 열린다', (tester) async {
      dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$label에서 예외가 났다');
      expect(find.text(expected), findsWidgets);
    });
  }

  testWidgets('드래그하면 버튼 위치가 바뀐다', (tester) async {
    // 하필 버튼이 확인하려는 UI를 가리면 테스터가 치울 수 있어야 한다
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final before = tester.getCenter(find.byIcon(Icons.bug_report));
    await tester.drag(find.byIcon(Icons.bug_report), const Offset(-100, -150));
    await tester.pumpAndSettle();
    final after = tester.getCenter(find.byIcon(Icons.bug_report));

    expect(after, isNot(before));
    expect(after.dx, lessThan(before.dx));
    expect(after.dy, lessThan(before.dy));
  });

  testWidgets('화면 밖으로는 나가지 않는다', (tester) async {
    // 끝까지 끌어도 버튼이 사라지면 다시 누를 수 없다
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.drag(find.byIcon(Icons.bug_report), const Offset(-9999, -9999));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byIcon(Icons.bug_report));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(find.byIcon(Icons.bug_report), findsOneWidget);
  });
}
