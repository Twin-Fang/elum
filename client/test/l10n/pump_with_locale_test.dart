import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

void main() {
  useFigmaViewport();
  tearDown(setAppL10nForTest);

  testWidgets('기본은 ko 다 - 문구와 appL10n 이 모두 ko', (tester) async {
    await pumpWithLocale(
      tester,
      Builder(builder: (context) => Text(context.l10n.commonConfirm)),
    );

    expect(find.text('확인'), findsOneWidget);
    expect(appL10n.localeName, 'ko');
  });

  testWidgets('언어를 바꿔 다시 띄우면 appL10n 도 따라간다', (tester) async {
    await pumpWithLocale(tester, const SizedBox());
    expect(appL10n.localeName, 'ko');

    await pumpWithLocale(tester, const SizedBox(), locale: const Locale('es'));
    await tester.pump();
    expect(appL10n.localeName, 'es');
  });

  testWidgets('locale 이 위젯 트리의 Localizations 와 context.l10n 에 닿는다', (tester) async {
    late BuildContext captured;
    await pumpWithLocale(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
      locale: const Locale('es'),
    );

    expect(Localizations.localeOf(captured).languageCode, 'es');
    expect(captured.l10n.localeName, 'es');
  });

  testWidgets('화면 크기와 ScreenUtil 설계 크기가 적용된다', (tester) async {
    late BuildContext captured;
    await pumpWithLocale(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );

    expect(MediaQuery.sizeOf(captured), const Size(393, 852));
    // 설계 크기와 뷰포트가 같으면 배율이 1 이다
    expect(1.sw, 393);
    expect(100.h, closeTo(100, 0.001));
  });

  testWidgets('textScale 인자가 위젯에 닿는다', (tester) async {
    late BuildContext captured;
    await pumpWithLocale(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
      textScale: 1.5,
    );

    expect(MediaQuery.textScalerOf(captured).scale(10), 15);
  });

  // 위 테스트가 건 배율이 다음 테스트로 새지 않는지 - 두 테스트를 이어 둔다
  testWidgets('textScale 은 테스트가 끝나면 원복된다 (앞 테스트 1.5 가 안 샌다)', (tester) async {
    late BuildContext captured;
    await pumpWithLocale(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );

    expect(MediaQuery.textScalerOf(captured).scale(10), 10);
  });

  testWidgets('theme 을 넘기면 비 ko 언어에서도 그 테마가 이긴다', (tester) async {
    final custom = ThemeData(primaryColor: const Color(0xFF123456));
    late BuildContext captured;
    await pumpWithLocale(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
      locale: const Locale('es'),
      theme: custom,
    );

    expect(Theme.of(captured).primaryColor, const Color(0xFF123456));
  });

  testWidgets('wrap 으로 바깥 껍질을 씌울 수 있다', (tester) async {
    await pumpWithLocale(
      tester,
      const Text('안쪽'),
      wrap: (app) => Directionality(textDirection: TextDirection.ltr, child: app),
    );

    expect(find.text('안쪽'), findsOneWidget);
  });

  testWidgets('wrap 이 호출되고 app 을 감싼다', (tester) async {
    var called = false;
    await pumpWithLocale(
      tester,
      const Text('안쪽'),
      wrap: (app) {
        called = true;
        return KeyedSubtree(key: const ValueKey('outer'), child: app);
      },
    );

    expect(called, isTrue);
    expect(find.byKey(const ValueKey('outer')), findsOneWidget);
  });

  testWidgets('음성 대조 - 넘치는 위젯은 헬퍼 아래에서 overflowed 예외로 잡힌다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(
        body: SizedBox(
          width: 50,
          child: Row(children: [Text('아주아주아주아주아주 긴 글이 좁은 폭에 들어간다')]),
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isNotNull, reason: '넘침을 못 잡으면 넘침 파일럿은 공허하다');
    expect(error.toString(), contains('overflowed'));
  });
}
