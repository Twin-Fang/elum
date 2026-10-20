import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../ads/application/tracking_prompt_gate.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/layout/adaptive_page_frame.dart';
import '../../../core/layout/layout_context_ext.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/layout/screen_layout_kind.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../credit/application/credit_start_gate.dart';
import '../../credit/domain/credit_summary.dart';
import '../../credit/presentation/credit_blocked_dialog.dart';
import '../../child/application/routine_auto_refresh.dart';
import '../../profile/application/profile_session.dart';
import '../application/guardian_child_identity.dart';
import '../application/example_routine_seeder.dart';
import '../application/home_routines.dart';
import '../application/home_coach_notifier.dart';
import '../application/routine_notifier.dart';
import 'guardian_home_header.dart';
import 'guardian_home_landscape_body.dart';
import 'widgets/create_routine_button.dart';
import 'widgets/home_coach_mark.dart';
import 'widgets/routine_summary_tile.dart';
import 'widgets/past_routine_section.dart';
import 'widgets/today_routine_section.dart';
import '../application/routine_providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/state/busy_state_mixin.dart';

/// Figma `보호자_홈`(931:3896 기본 / 931:4179 밀림 / 931:4879 삭제 확인).
///
/// 홈은 **오늘 일과 · 지난 일과 두 칸**이다. 섹션 순서는 상태에 따라 바뀌지 않는다 —
/// 목록이 비었다고 자리가 뒤바뀌면 다음에 열었을 때 어디를 봐야 할지 다시 찾게 된다.
///
/// **처음 들어오면 코치마크가 뜬다** (시안 1291:10801). 가리킬 위젯 셋의
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

  /// 추적 허용 팝업이 끝났는가. 팝업과 코치마크가 겹치면 팝업에 가려 안내가 보이지 않는다
  bool _isTrackingPromptDone = false;

  /// 다시 확인하는 간격과 최대 횟수(0.5초 × 60 = 30초). 팝업은 닫혀도 홈이 다시 그려지지
  /// 않아서, 기다렸다 물어보지 않으면 코치마크가 그 실행에서 영영 시작하지 못한다.
  static const _coachRetryEvery = Duration(milliseconds: 500);
  static const _coachMaxRetries = 60;

  /// 홈이 이만큼 맨 앞에 머물러야 시작한다. 공지 팝업이 연달아 뜰 때 앞 팝업이 닫히고
  /// 다음 팝업이 올라오는 찰나에 홈이 잠깐 맨 앞이 된다 — 그때 시작하면 다음 팝업이
  /// 코치마크 위에 겹친다 (실기기에서 확인).
  static const _coachSettleFor = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    // 온보딩에서 고른 예시 일과를 만든다 (#803). 대기 분류가 없으면 아무것도 하지 않는다
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedExampleRoutines());
  }

  /// 예시 생성 실패는 홈을 막지 않고 안내만 한다 (에러 코드 포함)
  Future<void> _seedExampleRoutines() async {
    final outcome = await ref.read(exampleRoutineSeederProvider).seedPending();
    if (!mounted || !outcome.shouldNotifyGuardian) return;
    showElumToast(
      context,
      '${context.l10n.exampleRoutinesFailed} ($_exampleSeedErrorCode)',
    );
  }

  /// 예시 일과 생성 실패 안내에 붙는 코드
  static const _exampleSeedErrorCode = 'E-EXAMPLE';

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
    if (!_isTrackingPromptDone) {
      waitForTrackingPrompt().whenComplete(() {
        _isTrackingPromptDone = true;
        // 기다리는 사이 화면이 바뀌었을 수 있어 처음부터 다시 따진다
        if (mounted) _maybeStartCoach();
      });
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _retryCoachLater();
      return;
    }
    final hasSwipeTarget = ref
        .read(homeRoutinesProvider)
        .any((r) => r.isEditableByMe);
    // 태블릿은 이룸이 화면 입구가 홈 밖(옆 메뉴, 글자 있음)이라 그 단계를 건너뛴다
    final started = ref
        .read(homeCoachProvider.notifier)
        .maybeStart(
          hasSwipeTarget: hasSwipeTarget,
          hasModeTarget: context.sizeClass == WindowSizeClass.compact,
        );
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

    // 연결된 이룸이가 하나도 없으면 이룸이 등록(온보딩)으로 보낸다.
    // 마지막 보호자로 나갔거나 다른 휴대폰에서 이룸이가 지워진 경우다. 라우터 가드는 화면을
    // 옮길 때만 평가되므로 머무는 중에 알게 되면 여기서 직접 옮긴다.
    ref.listen<bool>(profileSessionProvider.select((s) => s.noProfile), (
      _,
      none,
    ) {
      if (none) context.go(Routes.onboardingName);
    });

    // 함께하기로 선택한 이룸이 이름·캐릭터 (태블릿 옆 메뉴와 같은 값)
    final identity = ref.watch(guardianChildIdentityProvider);
    // 폰만 머리 줄(로고·이룸이 화면 배지)을 그린다. 태블릿은 옆 메뉴에 있다 (#798)
    final isPhone = context.sizeClass == WindowSizeClass.compact;

    // 코치마크: 오늘 일과를 받아 온 뒤에, 밀어 볼 수 있는 줄이 있는지 함께 알려 준다.
    // 받아 오지 못했으면(실패·로딩) 켜지 않는다 — 가리킬 대상이 있는지 모른다.
    // (두 값을 watch 해야 목록이 도착하는 순간 다시 그려져 여기로 들어온다.)
    final loaded = ref.watch(todayRoutinesProvider).hasValue;
    ref.watch(homeRoutinesProvider);
    if (loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartCoach());
    }

    final coachActive = ref.watch(homeCoachProvider.select((s) => s.active));

    final headerContent = GuardianHomeHeader(
      childName: identity.name,
      character: identity.character,
      modeKey: _modeKey,
      part: isPhone
          ? GuardianHomeHeaderPart.all
          : GuardianHomeHeaderPart.greeting,
    );
    // 태블릿 세로는 인사말이 맨 위라 상태 표시줄에 붙지 않게 숨 쉴 자리를 둔다 (폰은 머리 줄이 있다)
    final header = isPhone
        ? headerContent
        : Padding(
            padding: EdgeInsets.only(top: space.lg.h),
            child: headerContent,
          );
    // 코치마크가 가리키는 자리 — 키만 달고 모양은 건드리지 않는다.
    final createButton = Padding(
      padding: EdgeInsets.symmetric(horizontal: _listInset.w),
      child: KeyedSubtree(key: _createKey, child: const _StartRoutineButton()),
    );
    final sections = Padding(
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
    );

    // 코치마크가 떠 있는 동안은 뒤 목록이 움직이지 않게 잠근다 — 구멍은 한 번만 재서
    // 스크롤되면 대상과 어긋난다.
    final listPhysics = coachActive
        ? const NeverScrollableScrollPhysics()
        : null;

    // 가로 태블릿은 왼쪽 머리말·만들기, 오른쪽 목록 두 칸. 낮은 창(분할 보기)은 한 열로 접는다
    final metrics = context.layoutMetrics;
    final hasTwoPanes =
        metrics.isScaleOverridden &&
        metrics.isLandscape &&
        !metrics.isShortHeight;

    final scaffold = Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: hasTwoPanes
                  ? GuardianHomeLandscapeBody(
                      greeting: GuardianHomeHeader(
                        childName: identity.name,
                        character: identity.character,
                        modeKey: _modeKey,
                        part: GuardianHomeHeaderPart.greeting,
                      ),
                      createButton: createButton,
                      sections: sections,
                      listController: _scroll,
                      listPhysics: listPhysics,
                    )
                  : SingleChildScrollView(
                      controller: _scroll,
                      physics: listPhysics,
                      padding: EdgeInsets.only(bottom: space.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          header,
                          SizedBox(height: _toCreateButton.h),
                          createButton,
                          SizedBox(height: _toSections.h),
                          sections,
                        ],
                      ),
                    ),
            ),
            // 광고 띠는 보호자 틀(GuardianShell)이 하단 바 아래에 둔다 (#798)
          ],
        ),
      ),
    );

    // 이룸이가 다른 휴대폰에서 단계를 끝내도 알려 줄 길이 없다(푸시·소켓 없음).
    // 받아 둔 목록을 계속 쥐고 있어 마지막 단계를 끝낸 일과가 직전 퍼센트에 머물렀다 —
    // 완료 체크가 나오지 않아 "100% 가 안 뜬다"로 보였다. 이룸이 홈과 같은 주기로 다시 받는다.
    return AdaptivePageFrame(
      // 태블릿에서 두 칸이 아니면 가운데 열에 담는다 (폰은 그대로 지나간다)
      kind: hasTwoPanes
          ? ScreenLayoutKind.adaptive
          : ScreenLayoutKind.contentColumn,
      child: RoutineAutoRefresh(
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

class _StartRoutineButtonState extends ConsumerState<_StartRoutineButton>
    with BusyStateMixin<_StartRoutineButton> {
  @override
  Widget build(BuildContext context) =>
      CreateRoutineButton(onTap: _startRoutine, loading: busy);

  /// 일과 만들기 시작. 이전 입력이 남아 있으면 안 되므로 항상 초기화한다.
  ///
  /// 이번 주 크레딧을 다 썼으면 들어가지 않고 알린다 — 입력·질문·보상까지
  /// 다 적은 뒤 마지막에 막히면 적은 것이 헛수고가 된다.
  Future<void> _startRoutine() async {
    // 확인하는 동안만 잠근다. 결과가 null 일 수 있어 기록으로 감싸 건너뛴 경우와 가른다.
    final check = await runBusy(
      () async => (blocked: await creditBlocksRoutineStart(ref)),
    );
    if (check == null || !mounted) return;
    await continueRoutineStart(context, ref, check.blocked);
  }
}

/// 크레딧 확인을 마친 뒤 일과 만들기로 들어간다 (홈 · 일과관리 `+ 일과 만들기` 공통)
///
/// 막혔으면 안내만 띄우고 제자리에 남는다. 아니면 흐름 초기화 > 입력 화면.
Future<void> continueRoutineStart(
  BuildContext context,
  WidgetRef ref,
  CreditSummary? blocked,
) async {
  if (blocked != null) {
    // 안내 + (서버가 켜 둔 경우에만) 광고 보고 더 만들기. 들어가지 않고 제자리에 남는다.
    await showCreditBlockedDialog(context, ref, blocked);
    return;
  }
  ref.read(routineFlowProvider.notifier).reset();
  // push 가 끝나기를 기다리지 않는다 — 흐름이 `go` 로 홈에 돌아오면 그 Future 가
  // 끝나지 않을 수 있고, 그러면 버튼이 영영 눌리지 않는다.
  context.push(Routes.routineInput);
}
