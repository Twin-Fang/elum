import 'package:elum/features/ads/data/ad_banner_loader.dart';
import 'package:elum/features/ads/data/ad_strip_loader.dart';
import 'package:elum/features/ads/application/ad_gate.dart';
import 'package:elum/features/ads/presentation/ad_banner_slot.dart';
import 'package:elum/core/config/ad_ids.dart';
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
import 'package:elum/features/guardian/application/routine_providers.dart';

/// 홈 '지난 일과' 목록 사이의 배너 광고 (#741: 네이티브 medium 360dp 를 얇은 배너로 교체).
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

  late _CountingBanner banner;

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
          adBannerLoaderProvider.overrideWithValue(banner),
          // 하단 띠는 별도 로더 — 같은 집계에 합쳐 요청 수를 센다
          adStripLoaderProvider.overrideWithValue(_CountingStrip(banner)),
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

  setUp(() {
    banner = _CountingBanner();
  });

  testWidgets('지난 일과가 3개 이상이면 두 번째와 세 번째 사이에 광고가 한 개 끼인다', (tester) async {
    await pumpHome(tester, pastList: past(5));

    expect(find.text('광고'), findsOneWidget);
    expect(
      banner.callsOf(AdPlacement.bannerHomeMiddle),
      1,
      reason: '사이 광고는 한 개만 요청한다',
    );

    final second = tester.getTopLeft(find.text('지난 2')).dy;
    final adFrame = find.byKey(AdBannerSlot.frameKey);
    final ad = tester.getTopLeft(adFrame).dy;
    // 얇은 배너 한 칸: 라벨 포함 배너의 세 배 이내
    expect(tester.getSize(adFrame).height, lessThanOrEqualTo(150));
    final third = tester.getTopLeft(find.text('지난 3')).dy;
    expect(ad, greaterThan(second));
    expect(ad, lessThan(third));
  });

  testWidgets('지난 일과를 불러오지 못하면 광고도 없다', (tester) async {
    await pumpHome(tester, pastList: const [], pastFails: true);

    expect(find.text('광고'), findsNothing);
    expect(banner.calls, 0);
  });

  // 광고가 없을 때 목록이 광고 자리를 아예 안 둔 때와 같아야 한다 — 빈 자리 금지.
  testWidgets('광고 로드에 실패하면 목록이 광고 없는 홈과 똑같다', (tester) async {
    await pumpHome(tester, pastList: past(5), adsEnabled: false);
    final baseline = [
      for (var i = 1; i <= 5; i++) tester.getTopLeft(find.text('지난 $i')).dy,
    ];

    banner = _CountingBanner(fail: true);
    await pumpHome(tester, pastList: past(5));

    expect(banner.callsOf(AdPlacement.bannerHomeMiddle), 1);
    expect(find.text('광고'), findsNothing);
    expect([
      for (var i = 1; i <= 5; i++) tester.getTopLeft(find.text('지난 $i')).dy,
    ], baseline);

    // 다시 시도 타이머가 남지 않게 화면을 내린다.
    await tester.pumpWidget(const SizedBox());
  });

  // 일과가 적은 홈에 광고가 둘이나 붙으면 광고 화면처럼 보인다 — 오늘·지난 합이 5개 이상일 때만 둔다.
  testWidgets('오늘·지난 일과를 합쳐 4개면 하단 배너도 사이 배너도 요청하지 않는다', (tester) async {
    await pumpHome(
      tester,
      pastList: past(3),
      todayList: [routine('t1', '오늘 1')],
    );

    expect(banner.calls, 0);
  });

  // 하단 띠는 홈이 아니라 보호자 틀(GuardianShell)이 하단 바 아래에 둔다 (#798) — guardian_shell_test 가 본다.
  testWidgets('오늘·지난 일과를 합쳐 5개면 사이 배너를 요청하고 홈은 하단 띠를 두지 않는다', (tester) async {
    await pumpHome(
      tester,
      pastList: past(3),
      todayList: [routine('t1', '오늘 1'), routine('t2', '오늘 2')],
    );

    expect(banner.callsOf(AdPlacement.bannerHomeMiddle), 1);
    expect(banner.callsOf(AdPlacement.bannerHome), 0);
  });
}

class _CountingBanner implements AdBannerLoader {
  _CountingBanner({this.fail = false});

  final bool fail;
  final placements = <AdPlacement>[];

  int get calls => placements.length;

  int callsOf(AdPlacement placement) =>
      placements.where((p) => p == placement).length;

  @override
  Future<LoadedBanner?> load(AdPlacement placement) async {
    placements.add(placement);
    if (fail) return null;
    return LoadedBanner(
      height: 50,
      widget: const SizedBox(width: 320, height: 50),
      dispose: () {},
    );
  }
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

/// 하단 한 줄 띠 로더 대역: 요청을 [_CountingBanner] 집계에 합쳐 기록한다
class _CountingStrip implements AdStripLoader {
  _CountingStrip(this.counter);

  final _CountingBanner counter;

  @override
  Future<LoadedBanner?> load(AdPlacement placement, AdStripColors colors) =>
      counter.load(placement);
}
