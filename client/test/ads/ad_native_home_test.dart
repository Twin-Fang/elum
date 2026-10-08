import 'package:elum/features/ads/data/ad_banner_loader.dart';
import 'package:elum/features/ads/application/ad_gate.dart';
import 'package:elum/core/config/ad_ids.dart';
import 'package:elum/features/ads/data/ad_native_loader.dart';
import 'package:elum/features/ads/presentation/ad_native_slot.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/fake_reward_api.dart';
import '../helpers/test_storage.dart';
import 'package:elum/features/member/application/member_providers.dart';

/// 홈 '지난 일과' 목록 사이의 네이티브 광고 (#465).
///
/// 실패하면 항목 자체가 없고, 지난 일과가 없으면 넣지 않으며, 오늘 일과에는 끼지 않는다.
void main() {
  useFigmaViewport(size: const Size(393, 2400));

  Routine routine(String id, String title) => Routine(
    id: id,
    title: title,
    status: 'CONFIRMED',
    progressPercent: 100,
    steps: const [ActionCard(id: 'c1', stepOrder: 1, description: '첫 단계')],
  );

  List<Routine> past(int n) => [
    for (var i = 1; i <= n; i++) routine('p$i', '지난 $i'),
  ];

  late _CountingLoader loader;

  Future<void> pumpHome(
    WidgetTester tester, {
    required List<Routine> pastList,
    List<Routine> todayList = const [],
    bool pastFails = false,
    bool adsEnabled = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(_StubRepo()),
          todayRoutinesProvider.overrideWith((ref) async => todayList),
          myRoutinesProvider.overrideWith((ref) async => todayList),
          pastRoutinesProvider.overrideWith(
            (ref) async => pastFails ? throw StateError('실패') : pastList,
          ),
          memberProvider.overrideWith((ref) async => null),
          adsEnabledProvider.overrideWithValue(adsEnabled),
          adBannerLoaderProvider.overrideWithValue(_NoBanner()),
          adNativeLoaderProvider.overrideWithValue(loader),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: const GuardianHomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => loader = _CountingLoader());

  testWidgets('지난 일과가 3개 이상이면 두 번째와 세 번째 사이에 광고가 한 개 끼인다', (tester) async {
    await pumpHome(tester, pastList: past(5));

    expect(find.text('광고'), findsOneWidget);
    expect(loader.calls, 1, reason: '광고는 한 개만 요청한다');

    final second = tester.getTopLeft(find.text('지난 2')).dy;
    final ad = tester.getTopLeft(find.byKey(const Key('광고 틀'))).dy;
    final third = tester.getTopLeft(find.text('지난 3')).dy;
    expect(ad, greaterThan(second));
    expect(ad, lessThan(third));
  });

  testWidgets('긴 목록에서도 광고는 한 개뿐이고 일과는 모두 남는다', (tester) async {
    await pumpHome(tester, pastList: past(12));

    expect(find.text('광고'), findsOneWidget);
    for (var i = 1; i <= 12; i++) {
      expect(find.text('지난 $i'), findsOneWidget);
    }
  });

  testWidgets('지난 일과 제목 아래, 오늘 일과 영역 밖에 있다', (tester) async {
    await pumpHome(
      tester,
      pastList: past(4),
      todayList: [
        routine('t1', '오늘 1'),
        routine('t2', '오늘 2'),
        routine('t3', '오늘 3'),
      ],
    );

    final title = tester.getTopLeft(find.text('지난 일과')).dy;
    final ad = tester.getTopLeft(find.byKey(const Key('광고 틀'))).dy;
    expect(ad, greaterThan(title));
    expect(find.text('광고'), findsOneWidget, reason: '오늘 일과 사이에는 끼지 않는다');
  });

  testWidgets('오늘 일과가 길어도 지난 일과가 없으면 광고도 없다', (tester) async {
    await pumpHome(
      tester,
      pastList: const [],
      todayList: [for (var i = 1; i <= 6; i++) routine('t$i', '오늘 $i')],
    );

    expect(find.text('광고'), findsNothing);
    expect(loader.calls, 0);
  });

  // 2개부터는 언제나 일과 사이에 든다(#465 오클릭 방지, #540).
  testWidgets('지난 일과 2건이면 두 일과 사이에 넣는다', (tester) async {
    await pumpHome(tester, pastList: past(2));

    expect(find.text('광고'), findsOneWidget);
    expect(loader.calls, 1);

    final first = tester.getTopLeft(find.text('지난 1')).dy;
    final ad = tester.getTopLeft(find.byKey(const Key('광고 틀'))).dy;
    final second = tester.getTopLeft(find.text('지난 2')).dy;
    expect(ad, greaterThan(first));
    expect(ad, lessThan(second));
  });

  // 사이가 없는 1건만 끝에 붙는다. 아래가 하단 배너라 사이 광고보다 더 띄운다(#540).
  // 위 여백과 광고 내용은 같으므로 칸 높이 차이가 곧 아래 여백 차이다.
  testWidgets('지난 일과 1건이면 끝에 넣고 아래를 더 띄운다', (tester) async {
    await pumpHome(tester, pastList: past(3));
    final between = tester.getSize(find.byType(AdNativeSlot)).height;
    await tester.pumpWidget(const SizedBox());

    await pumpHome(tester, pastList: past(1));
    expect(find.text('광고'), findsOneWidget);
    final only = tester.getTopLeft(find.text('지난 1')).dy;
    expect(
      tester.getTopLeft(find.byKey(const Key('광고 틀'))).dy,
      greaterThan(only),
    );
    final trailing = tester.getSize(find.byType(AdNativeSlot)).height;
    expect(trailing, greaterThan(between));
  });

  // 빈 상태 아래에 광고를 두면 하단 배너와 함께 내용 없는 화면에 광고 둘이 붙는다.
  // AdMob 이 "콘텐츠보다 광고가 많은 화면"으로 볼 수 있어 넣지 않는다(#540).
  testWidgets('지난 일과가 0건이면 넣지 않는다', (tester) async {
    await pumpHome(tester, pastList: past(0));

    expect(find.text('광고'), findsNothing);
    expect(loader.calls, 0, reason: '넣지 않을 광고는 요청하지도 않는다');
  });

  testWidgets('지난 일과를 불러오지 못하면 광고도 없다', (tester) async {
    await pumpHome(tester, pastList: const [], pastFails: true);

    expect(find.text('광고'), findsNothing);
    expect(loader.calls, 0);
  });

  // 광고가 없을 때 목록이 광고 자리를 아예 안 둔 때와 같아야 한다 — 빈 자리 금지.
  testWidgets('광고 로드에 실패하면 목록이 광고 없는 홈과 똑같다', (tester) async {
    await pumpHome(tester, pastList: past(5), adsEnabled: false);
    final baseline = [
      for (var i = 1; i <= 5; i++) tester.getTopLeft(find.text('지난 $i')).dy,
    ];

    loader = _CountingLoader(fail: true);
    await pumpHome(tester, pastList: past(5));

    expect(loader.calls, 1);
    expect(find.text('광고'), findsNothing);
    expect([
      for (var i = 1; i <= 5; i++) tester.getTopLeft(find.text('지난 $i')).dy,
    ], baseline);

    // 다시 시도 타이머가 남지 않게 화면을 내린다.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('광고를 켜지 않은 환경에서는 광고를 요청하지 않는다', (tester) async {
    await pumpHome(tester, pastList: past(5), adsEnabled: false);

    expect(find.text('광고'), findsNothing);
    expect(loader.calls, 0);
  });
}

class _CountingLoader implements AdNativeLoader {
  _CountingLoader({this.fail = false});

  final bool fail;
  var calls = 0;

  @override
  Future<LoadedNative?> load(AdPlacement placement, int widthDp) async {
    calls++;
    if (fail) return null;
    return LoadedNative(
      height: 100,
      widget: const SizedBox(height: 100),
      dispose: () {},
    );
  }
}

class _NoBanner implements AdBannerLoader {
  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) async => null;
}

class _StubRepo with FakeRewardApi implements RoutineRepository {
  @override
  Future<List<Routine>> getMyRoutines() async => const [];

  @override
  Future<List<Routine>> getTodayRoutines() async => const [];

  @override
  Future<List<Routine>> getPastRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
