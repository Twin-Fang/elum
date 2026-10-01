import 'dart:async';

import 'package:elum/core/ads/ad_gate.dart';
import 'package:elum/core/ads/ad_ids.dart';
import 'package:elum/core/ads/ad_native_loader.dart';
import 'package:elum/core/ads/ad_native_slot.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/theme/theme_context_ext.dart';
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

class _PendingLoader implements AdNativeLoader {
  _PendingLoader(this.future);

  final Future<LoadedNative?> future;

  @override
  Future<LoadedNative?> load(AdPlacement placement, int widthDp) => future;
}

class _ThrowingLoader implements AdNativeLoader {
  @override
  Future<LoadedNative?> load(AdPlacement placement, int widthDp) =>
      Future.error(StateError('sdk'));
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
  testWidgets('로드 전에는 자리도 라벨도 없다', (tester) async {
    await tester.pumpWidget(
      _host(_PendingLoader(Completer<LoadedNative?>().future)),
    );
    await tester.pump();

    expect(find.text('광고'), findsNothing);
    expect(tester.getSize(find.byType(AdNativeSlot)).height, 0);
  });

  testWidgets('성공하면 "광고" 라벨과 함께 보인다', (tester) async {
    await tester.pumpWidget(_host(_FakeLoader([_native()])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('네이티브')), findsOneWidget);
    // 광고임을 알리는 라벨은 필수다 — 일과 카드로 오인해 누르면 무효 클릭이 된다.
    expect(find.text('광고'), findsOneWidget);
  });

  // 일과 카드(회색 면, 테두리 없음)와 모양이 달라야 한다.
  testWidgets('일과 카드와 다른 면(흰 바탕 + 테두리)에 담긴다', (tester) async {
    await tester.pumpWidget(_host(_FakeLoader([_native()])));
    await tester.pumpAndSettle();

    final frame = tester.widget<DecoratedBox>(find.byKey(const Key('광고 틀')));
    final deco = frame.decoration as BoxDecoration;
    expect(deco.border, isNotNull);
    final colors = tester.element(find.byKey(const Key('광고 틀'))).colors;
    expect(deco.color, isNot(colors.routineTileBg));
  });

  testWidgets('실패하면 항목 자체가 없다 — 빈 자리도 라벨도 남지 않는다', (tester) async {
    await tester.pumpWidget(_host(_FakeLoader([null])));
    await tester.pumpAndSettle();

    expect(find.text('광고'), findsNothing);
    expect(tester.getSize(find.byType(AdNativeSlot)).height, 0);
    final collapsed = _gap(tester);

    // 앞뒤 글자가 붙어 있다 — 광고가 없을 때와 슬롯을 아예 안 둔 때가 같다.
    expect(collapsed, lessThan(1));
  });

  testWidgets('로더가 예외를 던져도 화면은 살아 있다', (tester) async {
    await tester.pumpWidget(_host(_ThrowingLoader()));
    await tester.pumpAndSettle();

    expect(find.text('앞 일과'), findsOneWidget);
    expect(find.text('광고'), findsNothing);
    expect(tester.takeException(), isNull);
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

  testWidgets('다시 시도해서 성공하면 그때 나타난다', (tester) async {
    final loader = _FakeLoader([null, _native()]);
    await tester.pumpWidget(_host(loader));
    await tester.pump();
    expect(find.text('광고'), findsNothing);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('광고'), findsOneWidget);
  });

  testWidgets('광고를 켜지 않은 환경에서는 로더를 부르지도 않는다', (tester) async {
    final loader = _FakeLoader([_native()]);
    await tester.pumpWidget(_host(loader, enabled: false));
    await tester.pumpAndSettle();

    expect(loader.calls, 0);
    expect(find.text('광고'), findsNothing);
  });

  testWidgets('화면이 사라지면 광고를 해제한다', (tester) async {
    var disposed = 0;
    await tester.pumpWidget(
      _host(_FakeLoader([_native(onDispose: () => disposed++)])),
    );
    await tester.pumpAndSettle();
    expect(disposed, 0);

    await tester.pumpWidget(const SizedBox());
    expect(disposed, 1);
  });

  testWidgets('늦게 끝난 로드는 화면이 이미 없으면 그리지 않고 해제한다', (tester) async {
    final done = Completer<LoadedNative?>();
    var disposed = 0;
    await tester.pumpWidget(_host(_PendingLoader(done.future)));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    done.complete(_native(onDispose: () => disposed++));
    await tester.pump();

    expect(disposed, 1);
  });
}
