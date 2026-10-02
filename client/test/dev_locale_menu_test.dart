import 'package:elum/core/dev/dev_locale_override.dart';
import 'package:elum/core/dev/dev_tools_overlay.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// 개발자 도구 패널에서 언어를 강제한다 (스펙 4.1 ④).
void main() {
  Widget subject() => ProviderScope(
    overrides: [
      testStorageOverride(),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
    child: MaterialApp(
      home: const Scaffold(body: Text('앱 화면')),
      builder: (context, child) => DevToolsOverlay(
        onNavigate: (_) {},
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );

  testWidgets('언어 강제 메뉴에서 English 를 고르면 provider 가 en 이 되고 따르기로 풀 수 있다', (tester) async {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bug_report));
    await tester.pumpAndSettle();
    await tester.tap(find.text('언어 강제'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.text('앱 화면')));

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(container.read(devLocaleOverrideProvider), const Locale('en'));

    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(
      container.read(devLocaleOverrideProvider),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );

    await tester.tap(find.text('휴대폰 언어 따르기'));
    await tester.pumpAndSettle();
    expect(container.read(devLocaleOverrideProvider), isNull);
    expect(tester.takeException(), isNull);
  });
}
