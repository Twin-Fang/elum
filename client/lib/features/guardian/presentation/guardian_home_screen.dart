import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../ads/presentation/ad_banner_slot.dart';
import '../../../core/config/ad_ids.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/character_badge.dart';
import '../../credit/application/credit_start_gate.dart';
import '../../credit/presentation/credit_blocked_dialog.dart';
import '../../child/application/routine_auto_refresh.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../profile/application/profile_display_name.dart';
import '../../../shared/models/character.dart';
import '../../profile/application/profile_session.dart';
import '../application/home_coach_notifier.dart';
import '../application/routine_notifier.dart';
import 'widgets/create_routine_button.dart';
import 'widgets/home_coach_mark.dart';
import 'widgets/routine_summary_tile.dart';
import 'widgets/today_routine_section.dart';
import '../../member/application/member_providers.dart';
import '../application/routine_providers.dart';
import '../../../core/router/routes.dart';

/// Figma `보호자_홈`(931:3896 기본 / 931:4179 밀림 / 931:4879 삭제 확인 · 이슈 #258).
///
/// 개편으로 홈이 **오늘 일과 · 지난 일과 두 칸**으로 정리됐다.
///
/// - `추천 일과`가 빠졌다. 자리를 많이 쓰는 데 비해 눌리지 않았고, 그 자리에
///   지난 일과가 들어와 "전에 하던 것을 또 한다"는 실제 쓰임을 받는다.
/// - `새로운 일과 만들기`가 설명 붙은 카드에서 알약 버튼으로 줄었다.
/// - 섹션 순서가 상태에 따라 바뀌지 않는다. 오늘이 늘 먼저다 — 목록이 비었다고
///   자리가 뒤바뀌면 다음에 열었을 때 어디를 봐야 할지 다시 찾게 된다.
///
/// **처음 들어오면 코치마크가 뜬다** (시안 1291:10801 · 이슈 #505). 가리킬 위젯 셋의
/// [GlobalKey]를 여기서 들고 있고, 언제 띄울지는 [_maybeStartCoach] 가 정한다.
class GuardianHomeScreen extends ConsumerStatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  ConsumerState<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends ConsumerState<GuardianHomeScreen> {
  /// 코치마크가 가리킬 자리. 화면마다 따로 둔다 — 전환 중 홈이 둘 겹쳐도 키가 부딪히지 않는다.
  final _createKey = GlobalKey(debugLabel: 'coach.create');
  final _swipeKey = GlobalKey(debugLabel: 'coach.swipe');
  final _modeKey = GlobalKey(debugLabel: 'coach.mode');

  /// 홈 목록 스크롤. 코치마크가 켜질 때 맨 위로 되돌리고, 떠 있는 동안 잠그는 데 쓴다.
  final _scroll = ScrollController();

  /// 화면 전환이 끝나길 기다리는 중인가. 전환 도중에 띄우면 대상이 움직이는 중이라 위치가 어긋난다.
  bool _waitingRoute = false;

  /// Figma 실측 — 카드·버튼은 화면 끝에서 16, 글은 24
  static const _listInset = 16.0;

  /// 머리말 묶음 ↔ 만들기 버튼 32 · 버튼 ↔ 일과 40 · 섹션 사이 32 · 제목 ↔ 카드 8
  static const _toCreateButton = 32.0;
  static const _toSections = 40.0;
  static const _betweenSections = 32.0;

  static const _titleToList = 8.0;

  /// 홈이 맨 앞이 아닐 때(공지 팝업 등) 다시 확인할 타이머와 횟수.
  Timer? _coachRetry;
  var _coachRetries = 0;

  /// 홈이 맨 앞에서 가만히 있는지 지켜보는 타이머.
  Timer? _coachSettle;

  /// 다시 확인하는 간격과 최대 횟수(0.5초 × 60 = 30초). 팝업은 닫혀도 홈이 다시 그려지지
  /// 않아서, 기다렸다 물어보지 않으면 코치마크가 그 실행에서 영영 시작하지 못한다.
  static const _coachRetryEvery = Duration(milliseconds: 500);
  static const _coachMaxRetries = 60;

  /// 홈이 이만큼 맨 앞에 머물러야 시작한다. 공지 팝업이 연달아 뜰 때 앞 팝업이 닫히고
  /// 다음 팝업이 올라오는 찰나에 홈이 잠깐 맨 앞이 된다 — 그때 시작하면 다음 팝업이
  /// 코치마크 위에 겹친다 (실기기에서 확인).
  static const _coachSettleFor = Duration(milliseconds: 1200);

  @override
  void dispose() {
    _coachRetry?.cancel();
    _coachSettle?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// 코치마크를 띄워도 되는 때인지 보고, 맞으면 켠다.
  ///
  /// - 일과 목록을 **받아 온 뒤**여야 한다. 불러오는 중이거나 실패했으면 가리킬 줄이 있는지 모른다.
  /// - 홈이 맨 위에 있고 화면 전환이 끝난 뒤, [_coachSettleFor] 동안 그대로여야 한다.
  ///   다른 화면 위에 막만 덮이면 안 된다.
  void _maybeStartCoach() {
    if (!mounted) return;
    // 호출 시점의 값으로 다시 판단한다 — 기다리는 사이 목록이 바뀌었을 수 있다.
    if (!ref.read(todayRoutinesProvider).hasValue) return;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _coachSettle?.cancel();
      _coachSettle = null;
      _retryCoachLater();
      return;
    }

    final animation = route?.animation;
    if (animation != null && animation.status != AnimationStatus.completed) {
      if (_waitingRoute) return;
      _waitingRoute = true;
      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatus);
        _waitingRoute = false;
        _maybeStartCoach();
      }

      animation.addStatusListener(onStatus);
      return;
    }

    // 맨 앞이다. 바로 켜지 않고 잠시 지켜본다 — 그 사이 다시 가려지면 타이머가 취소된다.
    if (_coachSettle?.isActive ?? false) return;
    _coachSettle = Timer(_coachSettleFor, _startCoachNow);
  }

  void _startCoachNow() {
    _coachSettle = null;
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _retryCoachLater();
      return;
    }
    final hasSwipeTarget = ref
        .read(homeRoutinesProvider)
        .any((r) => r.isEditableByMe);
    final started = ref
        .read(homeCoachProvider.notifier)
        .maybeStart(hasSwipeTarget: hasSwipeTarget);
    // 대기 중 스크롤했거나 관성이 도는 중이면 버튼이 밀려 구멍이 어긋난다. 켜질 때만 맨 위로
    // 되돌린다 — 이미 본 사람의 스크롤까지 끌어올리면 안 된다. jumpTo 는 진행 중인 관성도 끊는다.
    // 구멍은 다음 프레임 이후에 재므로 이 이동이 먼저 반영된다.
    if (started && _scroll.hasClients) _scroll.jumpTo(0);
  }

  void _retryCoachLater() {
    if (_coachRetry?.isActive ?? false) return;
    if (_coachRetries++ >= _coachMaxRetries) return;
    _coachRetry = Timer(_coachRetryEvery, _maybeStartCoach);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    // 연결된 이룸이가 하나도 없으면 이룸이 등록(온보딩)으로 보낸다 (다중 보호자 #362 · E29).
    // 마지막 보호자로 나갔거나 다른 휴대폰에서 이룸이가 지워진 경우다. 라우터 가드는 화면을
    // 옮길 때만 평가되므로 머무는 중에 알게 되면 여기서 직접 옮긴다.
    ref.listen<bool>(profileSessionProvider.select((s) => s.noProfile), (
      _,
      none,
    ) {
      if (none) context.go(Routes.onboardingName);
    });

    // 함께하기로 선택한 이룸이 이름을 이룸이 홈과 동일하게 표시한다.
    final childName = resolveProfileDisplayName(
      ref.watch(memberProvider).value,
      ref.watch(profileSessionProvider.select((session) => session.selectedId)),
      ref.watch(onboardingProvider).displayName,
    );

    // 온보딩에서 고른 캐릭터(고양이/여우) — 홈 전역의 마스코트를 이 값으로 맞춘다.
    // 선택 전(구버전 데이터 등) 폴백은 이룸이 홈과 동일하게 고양이로 둔다.
    final character =
        ref.watch(onboardingProvider).cardCharacter ?? CardCharacter.cat;

    // 코치마크: 오늘 일과를 받아 온 뒤에, 밀어 볼 수 있는 줄이 있는지 함께 알려 준다.
    // 받아 오지 못했으면(실패·로딩) 켜지 않는다 — 가리킬 대상이 있는지 모른다.
    // (두 값을 watch 해야 목록이 도착하는 순간 다시 그려져 여기로 들어온다.)
    final loaded = ref.watch(todayRoutinesProvider).hasValue;
    ref.watch(homeRoutinesProvider);
    if (loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartCoach());
    }

    final coachActive = ref.watch(homeCoachProvider.select((s) => s.active));

    final scaffold = Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                // 코치마크가 떠 있는 동안은 뒤 목록이 움직이지 않게 잠근다 — 구멍은 한 번만 재서
                // 스크롤되면 대상과 어긋난다.
                physics: coachActive
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: EdgeInsets.only(bottom: space.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      childName: childName,
                      character: character,
                      modeKey: _modeKey,
                    ),
                    SizedBox(height: _toCreateButton.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _listInset.w),
                      // 코치마크가 가리키는 자리 — 키만 달고 모양은 건드리지 않는다.
                      child: KeyedSubtree(
                        key: _createKey,
                        child: const _StartRoutineButton(),
                      ),
                    ),
                    SizedBox(height: _toSections.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _listInset.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RoutineSectionTitle(
                            iconAsset: AppAssets.iconTodayRoutine,
                            label: context.l10n.guardianHomeTodayRoutine,
                          ),
                          SizedBox(height: _titleToList.h),
                          TodayRoutineSection(coachKey: _swipeKey),
                          SizedBox(height: _betweenSections.h),
                          RoutineSectionTitle(
                            iconAsset: AppAssets.iconTimePast,
                            label: context.l10n.guardianHomePastRoutine,
                          ),
                          SizedBox(height: _titleToList.h),
                          const PastRoutineSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 하단 배너(#281). 로드 전·실패 시 높이 0이라 스크롤 영역이 원래 크기 그대로다.
            const AdBannerSlot(placement: AdPlacement.bannerHome),
          ],
        ),
      ),
    );

    // 이룸이가 다른 휴대폰에서 단계를 끝내도 알려 줄 길이 없다(푸시·소켓 없음).
    // 받아 둔 목록을 계속 쥐고 있어 마지막 단계를 끝낸 일과가 직전 퍼센트에 머물렀다 —
    // 완료 체크가 나오지 않아 "100% 가 안 뜬다"로 보였다 (#535). 이룸이 홈과 같은 주기로 다시 받는다.
    return RoutineAutoRefresh(
      child: Stack(
        children: [
          scaffold,
          // 처음 들어왔을 때만 뜨는 안내. 평소에는 높이 0이라 아무것도 그리지 않는다.
          // Scaffold 밖이라 글 스타일을 주는 Material 이 없어 투명 Material 로 감싼다.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: HomeCoachMark(
                createKey: _createKey,
                swipeKey: _swipeKey,
                modeKey: _modeKey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `새로운 일과 만들기` + 시작 전 크레딧 확인.
///
/// 확인을 기다리는 동안 한 번 더 누르면 입력 화면이 두 번 쌓였다. 확인 중에는
/// 누름을 무시한다. 확인은 [creditStartCheckTimeout] 안에 끝나 오래 막히지 않는다.
class _StartRoutineButton extends ConsumerStatefulWidget {
  const _StartRoutineButton();

  @override
  ConsumerState<_StartRoutineButton> createState() =>
      _StartRoutineButtonState();
}

class _StartRoutineButtonState extends ConsumerState<_StartRoutineButton> {
  /// 크레딧을 확인하는 중인가. 화면을 다시 그릴 일이 없어 setState 없이 둔다.
  var _starting = false;

  @override
  Widget build(BuildContext context) =>
      CreateRoutineButton(onTap: _startRoutine);

  /// 일과 만들기 시작. 이전 입력이 남아 있으면 안 되므로 항상 초기화한다.
  ///
  /// 이번 주 크레딧을 다 썼으면 들어가지 않고 알린다 (#407) — 입력·질문·보상까지
  /// 다 적은 뒤 마지막에 막히면 적은 것이 헛수고가 된다.
  Future<void> _startRoutine() async {
    if (_starting) return;
    _starting = true;
    try {
      final blocked = await creditBlocksRoutineStart(ref);
      if (!mounted) return;
      if (blocked != null) {
        // 안내 + (서버가 켜 둔 경우에만) 광고 보고 더 만들기 (#464). 들어가지 않고 홈에 남는다.
        await showCreditBlockedDialog(context, ref, blocked);
        return;
      }
      ref.read(routineFlowProvider.notifier).reset();
      // push 가 끝나기를 기다리지 않는다 — 흐름이 `go` 로 홈에 돌아오면 그 Future 가
      // 끝나지 않을 수 있고, 그러면 버튼이 영영 눌리지 않는다.
      context.push(Routes.routineInput);
    } finally {
      _starting = false;
    }
  }
}

/// 로고 + 캐릭터 배지 + 설정 + 인사말 (Figma y=70~223).
///
/// 셋이 y=98을 가운데로 나란히 선다. 크기가 제각각(30 · 56 · 24)이라
/// 위를 맞추면 어긋나 보인다.
class _Header extends StatelessWidget {
  const _Header({
    required this.childName,
    required this.character,
    required this.modeKey,
  });

  final String childName;
  final CardCharacter character;

  /// 코치마크가 캐릭터 배지를 가리킬 때 쓰는 키.
  final GlobalKey modeKey;

  /// Figma 실측 — 안전영역(59) 기준 상단 여백
  static const _top = 11.0;
  static const _logoW = 80.0;
  static const _logoH = 30.0;
  static const _settings = 24.0;

  /// 배지 ↔ 설정 16 · 머리 줄 ↔ 인사말 11 · 인사말 ↔ 부제 12
  static const _badgeToSettings = 16.0;
  static const _rowToGreeting = 11.0;
  static const _greetingToSubtitle = 12.0;

  /// 2배를 넘을 때만 막는다. 그 아래는 null 이라 시스템 값을 그대로 쓴다.
  static TextScaler? _greetingScaler(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return scaler.scale(1) > 2.0 ? scaler.clamp(maxScaleFactor: 2.0) : null;
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: _top.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                AppAssets.homeLogo,
                width: _logoW.w,
                height: _logoH.h,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 이룸이 화면으로 넘어가는 입구. 보호자→이룸이 방향은 암호 없이 바로 간다.
                  // (이룸이→보호자 방향만 PIN으로 막는다)
                  AppPressable(
                    onTap: () => context.go(Routes.child),
                    scaleDown: AppPressable.scaleIcon,
                    // 이룸이 화면으로 가는 유일한 입구다. 그림뿐이라 이름을 주지
                    // 않으면 화면 낭독기로는 이 길을 찾을 수 없다 (#339).
                    semanticLabel: context.l10n.guardianHomeGoChildScreen,
                    child: KeyedSubtree(
                      key: modeKey,
                      child: CharacterBadge(character: character),
                    ),
                  ),
                  SizedBox(width: _badgeToSettings.w),
                  // 설정 진입점 (#181). 개편 시안에서 배지 오른쪽으로 옮겨졌다.
                  AppPressable(
                    // push로 연다. go는 스택을 교체해 설정 화면의 뒤로가기가
                    // 돌아갈 곳을 잃는다 — 화살표도 기기 뒤로가기도 먹통이 된다 (이슈 #194).
                    onTap: () => context.push(Routes.guardianSettings),
                    scaleDown: AppPressable.scaleIcon,
                    semanticLabel: context.l10n.guardianHomeSettings,
                    child: SvgPicture.asset(
                      AppAssets.iconSettings,
                      // 정사각형 아이콘 — 가로세로 모두 .w
                      width: _settings.w,
                      height: _settings.w,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: _rowToGreeting.h),
          Text(
            // Figma 문구. 줄바꿈 위치도 디자인이 정한 대로다.
            context.l10n.guardianHomeGreeting(childName),
            // 이미 24 짜리 큰 제목이라 최대 배율에서는 한 글자씩 꺾인다. 이 글만 2배에서 멈춘다.
            textScaler: _greetingScaler(context),
            style: context.typo.greeting.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: _greetingToSubtitle.h),
          Text(
            context.l10n.guardianHomeSubtitle,
            style: context.typo.body.copyWith(color: colors.routineTileLabel),
          ),
        ],
      ),
    );
  }
}
