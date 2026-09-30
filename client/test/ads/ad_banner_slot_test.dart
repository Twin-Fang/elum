import 'dart:async';

import 'package:elum/core/ads/ad_banner_loader.dart';
import 'package:elum/core/ads/ad_banner_slot.dart';
import 'package:elum/core/ads/ad_gate.dart';
import 'package:elum/core/ads/ad_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 호출 순서대로 미리 정한 결과를 돌려주는 가짜 로더. null은 실패.
class _FakeLoader implements AdBannerLoader {
  _FakeLoader(this.results);

  final List<LoadedBanner?> results;
  var calls = 0;

  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) async {
    final r = calls < results.length ? results[calls] : null;
    calls++;
    return r;
  }
}

/// 끝나지 않는 로드.
class _PendingLoader implements AdBannerLoader {
  _PendingLoader(this.future);

  final Future<LoadedBanner?> future;

  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) => future;
}

class _ThrowingLoader implements AdBannerLoader {
  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) =>
      Future.error(StateError('sdk'));
}

Widget _host(AdBannerLoader loader, {bool enabled = true}) => ProviderScope(
  overrides: [
    adBannerLoaderProvider.overrideWithValue(loader),
    adsEnabledProvider.overrideWithValue(enabled),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Expanded(child: Text('본문')),
          AdBannerSlot(placement: AdPlacement.bannerHome),
        ],
      ),
    ),
  ),
);

LoadedBanner _banner({VoidCallback? onDispose}) => LoadedBanner(
  height: 60,
  widget: const SizedBox(key: Key('배너'), height: 60),
  dispose: onDispose ?? () {},
);

void main() {
  testWidgets('로드 전에는 자리를 차지하지 않는다', (tester) async {
    final loader = _PendingLoader(Completer<LoadedBanner?>().future);
    await tester.pumpWidget(_host(loader));
    await tester.pump();
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 0);
  });

  testWidgets('로드에 성공하면 그 높이만큼 자리를 차지한다', (tester) async {
    await tester.pumpWidget(_host(_FakeLoader([_banner()])));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('배너')), findsOneWidget);
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 60);
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

  testWidgets('게이트가 꺼져 있으면 로드하지 않는다', (tester) async {
    final loader = _FakeLoader([_banner()]);
    await tester.pumpWidget(_host(loader, enabled: false));
    await tester.pumpAndSettle();
    expect(loader.calls, 0);
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 0);
  });

  testWidgets('화면을 떠나면 광고를 해제한다', (tester) async {
    var disposed = 0;
    await tester.pumpWidget(
      _host(_FakeLoader([_banner(onDispose: () => disposed++)])),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(disposed, 1);
  });

  testWidgets('로드가 늦게 끝나도 이미 떠난 화면에는 그리지 않고 해제한다', (tester) async {
    final completer = Completer<LoadedBanner?>();
    await tester.pumpWidget(_host(_PendingLoader(completer.future)));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    var disposed = 0;
    completer.complete(_banner(onDispose: () => disposed++));
    await tester.pump();
    expect(disposed, 1);
  });

  testWidgets('여백은 광고가 뜬 뒤에만 생긴다 — 광고가 없으면 자리가 0이다', (tester) async {
    Widget hostWithPadding(AdBannerLoader loader) => ProviderScope(
      overrides: [
        adBannerLoaderProvider.overrideWithValue(loader),
        adsEnabledProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: AdBannerSlot(
            placement: AdPlacement.bannerHomeMiddle,
            padding: EdgeInsets.only(top: 24),
          ),
        ),
      ),
    );

    // 실패: 여백까지 0 — 목록 중간에 넣어도 빈 줄이 남지 않는다.
    await tester.pumpWidget(hostWithPadding(_FakeLoader([null])));
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 0);

    // 슬롯 상태가 남지 않게 화면을 내렸다가 다시 올린다.
    await tester.pumpWidget(const SizedBox());

    // 성공: 배너 높이 60 + 위 여백 24.
    await tester.pumpWidget(hostWithPadding(_FakeLoader([_banner()])));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 84);
  });

  testWidgets('로더가 예외를 던져도 화면은 살아 있다', (tester) async {
    await tester.pumpWidget(_host(_ThrowingLoader()));
    await tester.pump();
    await tester.pump();
    expect(find.text('본문'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
