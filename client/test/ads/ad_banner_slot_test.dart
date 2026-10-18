import 'package:elum/features/ads/data/ad_banner_loader.dart';
import 'package:elum/features/ads/presentation/ad_banner_slot.dart';
import 'package:elum/features/ads/application/ad_gate.dart';
import 'package:elum/core/config/ad_ids.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 호출 순서대로 미리 정한 결과를 돌려주는 가짜 로더. null은 실패.
class _FakeLoader implements AdBannerLoader {
  _FakeLoader(this.results);

  final List<LoadedBanner?> results;
  var calls = 0;
  final requestedColors = <AdStripColors>[];

  @override
  Future<LoadedBanner?> load(
    AdPlacement placement,
    AdStripColors colors,
  ) async {
    requestedColors.add(colors);
    final r = calls < results.length ? results[calls] : null;
    calls++;
    return r;
  }
}

class _ThrowingLoader implements AdBannerLoader {
  @override
  Future<LoadedBanner?> load(AdPlacement placement, AdStripColors colors) =>
      Future.error(StateError('sdk'));
}

Widget _host(AdBannerLoader loader, {bool enabled = true}) => ProviderScope(
  overrides: [
    adBannerLoaderProvider.overrideWithValue(loader),
    adsEnabledProvider.overrideWithValue(enabled),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(
      body: Column(
        children: [
          Expanded(child: Text('본문')),
          AdBannerSlot(placement: AdPlacement.bannerHome),
        ],
      ),
    ),
  ),
);

void main() {
  // 배너가 뜨면 본문과 구분되는 얇은 층에 담긴다. 층이 없으면 광고가 본문 끝에 떠 있는 것처럼 보인다
  testWidgets('성공하면 띠 높이(44dp)만큼 화면 폭 전체의 층에 담긴다', (tester) async {
    final loader = _FakeLoader([
      LoadedBanner(
        height: 44,
        widget: const SizedBox(key: Key('배너'), width: 320, height: 44),
        dispose: () {},
      ),
    ]);
    await tester.pumpWidget(_host(loader));
    await tester.pumpAndSettle();

    final strip = find.byKey(AdBannerSlot.stripKey);
    expect(strip, findsOneWidget);
    expect(tester.getSize(strip).height, 44);
    expect(
      tester.getSize(strip).width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    expect(find.byKey(const Key('배너')), findsOneWidget);
  });

  // 띠 색은 앱 색 토큰에서 와야 한다. 하드코딩되면 테마와 어긋난다
  testWidgets('로드 때 앱 색 토큰을 ARGB로 네이티브에 넘긴다', (tester) async {
    final loader = _FakeLoader([null]);
    await tester.pumpWidget(_host(loader));
    await tester.pump();
    await tester.pump();

    final colors = AppTheme.light.extension<AppColors>()!;
    final requested = loader.requestedColors.single;
    expect(requested.background, colors.surface.toARGB32());
    expect(requested.headline, colors.textPrimary.toARGB32());
    expect(requested.badgeText, colors.textSecondary.toARGB32());
  });

  testWidgets('테마 색이 바뀌면 새 색으로 다시 로드한다', (tester) async {
    final loader = _FakeLoader([
      LoadedBanner(height: 44, widget: const SizedBox(), dispose: () {}),
      LoadedBanner(height: 44, widget: const SizedBox(), dispose: () {}),
    ]);
    final theme = ValueNotifier<ThemeData>(AppTheme.light);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adBannerLoaderProvider.overrideWithValue(loader),
          adsEnabledProvider.overrideWithValue(true),
        ],
        child: ValueListenableBuilder<ThemeData>(
          valueListenable: theme,
          builder: (_, value, _) => MaterialApp(
            theme: value,
            home: const Scaffold(
              body: Column(
                children: [
                  Expanded(child: Text('본문')),
                  AdBannerSlot(placement: AdPlacement.bannerHome),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loader.calls, 1);

    final light = AppTheme.light.extension<AppColors>()!;
    theme.value = AppTheme.light.copyWith(
      extensions: [light.copyWith(surface: const Color(0xFF111111))],
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(loader.calls, 2);
    expect(loader.requestedColors.last.background, 0xFF111111);
  });

  testWidgets('실패하면 높이 0으로 남고 30초·60초 뒤 한 번씩만 다시 시도한다', (tester) async {
    final loader = _FakeLoader([null, null, null, null]);
    await tester.pumpWidget(_host(loader));
    await tester.pump();
    await tester.pump();
    expect(loader.calls, 1);
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 0);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(loader.calls, 2);

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(loader.calls, 3);

    // 더는 시도하지 않는다.
    await tester.pump(const Duration(minutes: 10));
    await tester.pump();
    expect(loader.calls, 3);
  });

  testWidgets('로더가 예외를 던져도 화면은 살아 있다', (tester) async {
    await tester.pumpWidget(_host(_ThrowingLoader()));
    await tester.pump();
    await tester.pump();
    expect(find.text('본문'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
