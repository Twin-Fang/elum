
import 'package:elum/features/ads/application/ad_gate.dart';
import 'package:elum/core/config/ad_ids.dart';
import 'package:elum/features/ads/data/ad_native_loader.dart';
import 'package:elum/features/ads/presentation/ad_native_slot.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 호출 순서대로 미리 정한 결과를 돌려주는 가짜 로더. null은 실패.
class _FakeLoader implements AdNativeLoader {
  _FakeLoader(this.results);

  final List<LoadedNative?> results;
  var calls = 0;

  @override
  Future<LoadedNative?> load(AdPlacement placement, int widthDp) async {
    final r = calls < results.length ? results[calls] : null;
    calls++;
    return r;
  }
}

Widget _host(AdNativeLoader loader, {bool enabled = true}) => ProviderScope(
  overrides: [
    adNativeLoaderProvider.overrideWithValue(loader),
    adsEnabledProvider.overrideWithValue(enabled),
  ],
  child: ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Column(
          children: [
            Text('앞 일과'),
            AdNativeSlot(placement: AdPlacement.nativeHomePast),
            Text('뒤 일과'),
          ],
        ),
      ),
    ),
  ),
);

LoadedNative _native({VoidCallback? onDispose}) => LoadedNative(
  height: 100,
  widget: const SizedBox(key: Key('네이티브'), height: 100),
  dispose: onDispose ?? () {},
);

/// 슬롯이 차지한 세로 길이. 앞뒤 글자 사이 간격으로 잰다.
double _gap(WidgetTester tester) =>
    tester.getTopLeft(find.text('뒤 일과')).dy -
    tester.getBottomLeft(find.text('앞 일과')).dy;

void main() {

  testWidgets('실패하면 항목 자체가 없다 — 빈 자리도 라벨도 남지 않는다', (tester) async {
    await tester.pumpWidget(_host(_FakeLoader([null])));
    await tester.pumpAndSettle();

    expect(find.text('광고'), findsNothing);
    expect(tester.getSize(find.byType(AdNativeSlot)).height, 0);
    final collapsed = _gap(tester);

    // 앞뒤 글자가 붙어 있다 — 광고가 없을 때와 슬롯을 아예 안 둔 때가 같다.
    expect(collapsed, lessThan(1));
  });

  testWidgets('실패하면 30초·60초 뒤 한 번씩만 다시 시도한다', (tester) async {
    final loader = _FakeLoader([null, null, null, _native()]);
    await tester.pumpWidget(_host(loader));
    await tester.pump();
    expect(loader.calls, 1);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(loader.calls, 2);
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(loader.calls, 3);

    // 세 번째 실패 뒤에는 그만둔다.
    await tester.pump(const Duration(minutes: 5));
    expect(loader.calls, 3);
    expect(find.text('광고'), findsNothing);
  });

}
