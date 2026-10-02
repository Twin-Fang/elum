import 'package:elum/core/dev/dev_locale_override.dart';
import 'package:elum/core/l10n/effective_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 언어 강제는 QA·시연 전용이다. **릴리스 빌드(개발자 도구 꺼짐)에서는 어떤 경로로도 먹지 않는다.**
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => binding.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')]);
  tearDown(() {
    binding.platformDispatcher.clearLocalesTestValue();
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  test('개발자 도구가 꺼져 있으면 강제 값이 들어오지 않는다', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=false');
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(devLocaleOverrideProvider.notifier).set(const Locale('ja'));

    expect(c.read(devLocaleOverrideProvider), isNull);
  });

  test('켜져 있으면 강제 값이 저장되고 null 로 풀 수 있다', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final notifier = c.read(devLocaleOverrideProvider.notifier);

    notifier.set(const Locale('ja'));
    expect(c.read(devLocaleOverrideProvider), const Locale('ja'));

    notifier.set(null);
    expect(c.read(devLocaleOverrideProvider), isNull);
  });

  test('effectiveAppLocale: 강제가 없으면 휴대폰 언어를 따른다', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    expect(effectiveAppLocale(), const Locale('ko'));

    binding.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
    expect(effectiveAppLocale(), const Locale('es'));

    binding.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    expect(effectiveAppLocale(), const Locale('en'));
  });

  test('effectiveAppLocale: 개발자 도구가 켜져 있으면 강제가 이긴다', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    expect(effectiveAppLocale(devOverride: const Locale('ja')), const Locale('ja'));
  });

  test('effectiveAppLocale: 꺼져 있으면 강제 값이 넘어와도 무시한다 — 릴리스 빌드 방어선', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=false');
    expect(effectiveAppLocale(devOverride: const Locale('ja')), const Locale('ko'));
  });
}
