import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_scaffold.dart';
import '../../data/routine_repository.dart';
import 'aurora_background.dart';
import 'routine_flow_backdrop.dart';

/// 일과 만들기 흐름의 공통 뼈대.
///
/// 흐름 화면(로딩·추가질문·보상·카드확인)이 같은 상단 버튼을 공유한다.
/// 배경은 흐름이 **한 장**([RoutineFlowBackdrop])을 함께 쓰고, 여기서는 그 위에
/// 투명하게 선다 (#380). 화면마다 [AuroraBackground]를 그리면 전환마다 새로
/// 만들어져 움직임이 튀고, 색이 다른 화면이 경계선째 밀려 들어온다.
///
/// Figma는 뒤로가기(x=24)와 홈(x=72)을 나란히 둔다. 홈은 흐름을 중간에
/// 빠져나가는 길이다 — 일과 만들기는 단계가 길어 되돌아갈 방법이 필요하다.
class RoutineFlowScaffold extends ConsumerWidget {
  const RoutineFlowScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.bottomButton,
    this.pinCtaToFigmaY = false,
    this.aurora = AuroraTone.input,
    this.leave,
    this.backLeavesFlow = false,
    this.belowButton,
  });

  final Widget child;

  /// null이면 뒤로가기를 그리지 않는다 (되돌릴 수 없는 단계)
  final VoidCallback? onBack;

  /// 하단 고정 CTA. 입력·로딩 화면에는 없다.
  final Widget? bottomButton;

  /// CTA를 **시안 자리(y=675)에 고정**할지.
  ///
  /// 기본은 화면 바닥에 붙인다 — 카드확인처럼 내용이 길어 CTA가 아래로 내려오는
  /// 화면이 그렇다. 추가질문(`262:4854`)은 시안이 `y=675`로, 약관·목표와 같은
  /// 앱 표준 자리다. 바닥에 붙여 두어 **66 아래**에 있었다 (#297).
  final bool pinCtaToFigmaY;

  /// 배경 글로우의 색. **Figma에 Gradient가 없는 화면은 [AuroraTone.none]으로 끈다.**
  ///
  /// 글로우는 입력 화면(238:1643의 Gradient 238:1728)을 재현한 것이라
  /// 모든 화면에 있는 배경이 아니다. 카드확인(262:5124)은 단색 배경뿐이고,
  /// 보상 설정(1082:4709)은 분홍이다 (#380).
  ///
  /// ⚠️ 흐름 배경([RoutineFlowBackdrop]) 위에서는 이 값으로 그리지 않는다 —
  /// 라우터가 위치로 색을 정한다(`routineFlowToneOf`). 여기 값은 흐름 밖에서
  /// 단독으로 열렸을 때(테스트·대조 렌더) 쓴다. 두 값이 같은지는
  /// `routine_flow_backdrop_test`가 본다.
  final AuroraTone aurora;

  /// CTA **아래**에 붙는 빠져나가는 길 (`나중에 할게요`). [ElumScaffold]와 같은 자리다.
  ///
  /// [pinCtaToFigmaY]와 함께 쓰면 CTA는 시안 자리(y=675)에 그대로 서고, 이 줄이
  /// 그 아래 24(y=765)에 붙는다.
  final Widget? belowButton;

  /// CTA 하단(741) ↔ 보조 동작(765) 간격. 시안 실측 (`ElumScaffold`와 같다).
  static const _belowGap = 24.0;

  /// 보조 동작 하단(781)에서 프레임 하단(852)까지.
  static const _belowBottom = 71.0;

  /// 여기서 흐름을 떠나면 무엇이 남는가 — 나가기 전에 그것을 말하고 묻는다
  /// (이슈 #242 · #387). null 이면 잃을 것이 없어 묻지 않는다.
  ///
  /// **일과를 만들다 중간에 나가면 되돌릴 수 없다.** 입력한 문장도, AI가 만든
  /// 카드도 남지 않는데 카드 생성은 30초 넘게 걸린다 — 잘못 눌러 날리면 그 시간을
  /// 다시 쓴다. 다만 카드를 만든 뒤에는 서버에 임시저장으로 **남는다** — 그때
  /// `사라져요`라고 하면 사실이 아니다. 그래서 시점마다 [RoutineLeave]가 다르다.
  ///
  /// 뒤로가기·홈·**시스템 뒤로가기(제스처)** 를 모두 잡는다. 화면 안의 버튼만
  /// 막으면 제스처로 그냥 빠져나간다.
  ///
  /// 잃을 것이 없는 화면에서는 null 로 둔다 — 물어볼 것이 없는데 묻는 팝업이
  /// 가장 성가시다.
  final RoutineLeave? leave;

  /// 뒤로가 **흐름을 떠나는가** (#387 D1 · D3).
  ///
  /// false(기본)면 뒤로는 흐름 안에서 한 칸 돌아가는 것이다 — 적은 것이 그대로
  /// 남으므로 **묻지 않는다.** 보상·추가 질문·로딩이 그렇다. 떠나는 것은 홈뿐이라
  /// 홈만 [leave] 를 묻는다.
  ///
  /// true 면 뒤로도 떠나는 것이다 — 홈과 똑같이 묻고, 나가면 [onBack] 이 흐름을
  /// 통째로 닫는다([leaveRoutineFlow]). 카드 확인이 그렇다. 거기서 한 칸 돌아가면
  /// 이미 임시저장에 있는 일과를 두고 추가 질문 화면이 `남지 않아요` 라고 겁을 주고,
  /// 되돌아가 바꾼 보상·답은 생성 막음에 걸려 조용히 버려진다(E2E 2차 D1·D2).
  /// 기기 뒤로·스와이프도 화살표와 같은 길을 간다.
  final bool backLeavesFlow;

  /// 나가도 되는지 묻는다. 물어보지 않기로 했으면 그대로 통과시킨다.
  ///
  /// 임시저장에 남기고 나가면 목록을 다시 받는다 — 카드 확인에서 문장을 고쳤을 수
  /// 있고, 안 받으면 임시저장 화면이 옛 목록을 보여준다 (#387).
  ///
  /// **나간 다음 프레임에 받는다.** 지금은 돌아갈 화면(임시저장·홈)이 이 화면 아래에
  /// 가려져 구독을 쉬고 있다. 쉬는 동안 목록을 무효화하면, 그 화면이 다시 보이는
  /// 순간 파생 목록이 빌드 도중에 다시 그리라고 요청해 디버그에서
  /// `markNeedsBuild() called during build` 가 난다 (실제로 났다).
  Future<bool> _mayLeave(
    BuildContext context,
    WidgetRef ref, {
    required bool back,
  }) async {
    final kind = leave;
    if (kind == null || (back && !backLeavesFlow)) return true;
    final container = ProviderScope.containerOf(context, listen: false);
    final ok = await confirmLeaveRoutineFlow(context, kind);
    if (ok && kind != RoutineLeave.discard) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => container.refreshRoutines(),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;

    return PopScope(
      // 시스템 뒤로가기(제스처·버튼)를 여기서 잡는다. 한 칸 돌아가는 뒤로는 그냥
      // 보내고, 흐름을 떠나는 뒤로만 붙잡아 화살표와 같은 길([onBack])로 보낸다.
      canPop: !backLeavesFlow,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _mayLeave(context, ref, back: true);
        if (!ok || !context.mounted) return;
        dismissKeyboard();
        final back = onBack;
        back == null ? leaveRoutineFlow(context) : back();
      },
      child: _scaffold(context, ref, space),
    );
  }

  Widget _scaffold(BuildContext context, WidgetRef ref, AppSpacing space) {
    // 흐름 배경 위라면 바탕을 칠하지 않는다 — 배경이 비쳐야 색이 번지는 게 보인다.
    final onBackdrop = RoutineFlowBackdrop.isPresent(context);

    return Scaffold(
      backgroundColor: onBackdrop
          ? Colors.transparent
          : context.colors.background,
      // 키보드가 올라와도 배경이 밀려 찌그러지지 않게 한다
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (!onBackdrop && aurora != AuroraTone.none)
            Positioned.fill(child: AuroraBackground(tone: aurora)),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onBack: onBack == null
                      ? null
                      : () async {
                          if (!await _mayLeave(context, ref, back: true)) {
                            return;
                          }
                          dismissKeyboard();
                          onBack!();
                        },
                  onHome: () async {
                    final ok = await _mayLeave(context, ref, back: false);
                    if (ok && context.mounted) context.go(Routes.guardian);
                  },
                ),
                Expanded(child: child),
                if (bottomButton != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      space.buttonMarginH,
                      space.md,
                      space.buttonMarginH,
                      // 시안 자리에 고정할 때는 `ElumScaffold`와 같은 식으로
                      // 역산한다 — 프레임 하단(852)에서 CTA 하단(741)까지 111을
                      // 두되 기기 홈인디케이터만큼은 뺀다. 아래에 보조 동작이
                      // 붙으면 그 줄(781)부터 잰다.
                      pinCtaToFigmaY
                          ? ((belowButton == null
                                            ? 852 - space.ctaTop - space.buttonH
                                            : _belowBottom)
                                        .h -
                                    MediaQuery.paddingOf(context).bottom)
                                .clamp(0.0, double.infinity)
                          : space.lg,
                    ),
                    child: belowButton == null
                        ? bottomButton
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              bottomButton!,
                              SizedBox(height: _belowGap.h),
                              belowButton!,
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 뒤로가기 + 홈 (Figma x=24 / x=72, y=87)
class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack, required this.onHome});

  final VoidCallback? onBack;

  /// 홈도 나가는 길이다 — 뒤로가기와 같은 확인을 거친다 (#242).
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 시안(262:4766)은 상단 아이콘이 y=87 에서 시작한다. 안전영역(59) 안에서
      // 28 이다 — 12 로 두면 화면 전체가 16 위로 뜬다 (#297).
      padding: EdgeInsets.only(left: context.space.screenH, top: 28.h),
      child: Row(
        children: [
          if (onBack != null)
            AppPressable(
              onTap: onBack,
              scaleDown: AppPressable.scaleIcon,
              // 일과 만들기 흐름 화면 전부가 이 상단바를 쓴다 — 여기가 비면 다 빈다 (#339)
              semanticLabel: ElumScaffold.backLabel,
              // 정사각형 아이콘이라 가로세로 모두 .w
              // 자리는 아이콘 크기 그대로 두고 **그 위로** 40×40 누름 영역을 덮는다 (#306).
              // 자리째 키우면 상단바가 높아져 화면 전체가 아래로 밀린다.
              child: SizedBox(
                width: 24.w,
                height: 24.w,
                child: OverflowBox(
                  maxWidth: 40.w,
                  maxHeight: 40.w,
                  child: SizedBox(
                    width: 40.w,
                    height: 40.w,
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.iconBack,
                        width: 24.w,
                        height: 24.w,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(width: 24.w),
          // 뒤로가기 자리(24~48) → 집 상자(시안 x=74). 24를 띄우면 2가 모자란다 (#297).
          SizedBox(width: 26.w),
          AppPressable(
            onTap: onHome,
            scaleDown: AppPressable.scaleIcon,
            semanticLabel: '홈으로 가기',
            // 자리는 아이콘 크기 그대로 두고 **그 위로** 40×40 누름 영역을 덮는다 (#306).
            // 자리째 키우면 상단바가 높아져 화면 전체가 아래로 밀린다.
            child: SizedBox(
              width: 24.w,
              height: 24.w,
              child: OverflowBox(
                maxWidth: 40.w,
                maxHeight: 40.w,
                child: SizedBox(
                  width: 40.w,
                  height: 40.w,
                  child: Center(
                    child: SvgPicture.asset(
                      AppAssets.iconHome,
                      width: 24.w,
                      height: 24.w,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 일과 만들기에서 나가도 되는지 묻는다 (이슈 #242).
///
/// 이 스캐폴드를 쓰지 않는 화면(일과 입력)도 같은 문구·같은 무게를 써야 하므로
/// 함수로 뺐다. 화면마다 따로 쓰면 문구가 어긋난다.
/// 화면을 닫기 직전에 키보드를 내린다 (이슈 #301).
///
/// **iOS는 입력칸이 포커스를 쥔 채 라우트가 닫히면 키보드를 그대로 둔다.** 홈으로
/// 돌아왔는데 키보드가 화면 아래를 덮고 있어 빈 곳을 한 번 눌러야 사라진다.
/// 안드로이드는 대개 알아서 내려 주므로 iOS에서만 드러난다.
///
/// 나가는 길마다 흩뿌리지 않고 이 함수를 거치게 한다 — 길이 하나 더 생겨도
/// 빠뜨리지 않는다. `dispose`에 넣는 것으로는 늦다. 그때는 라우트가 이미 닫힌
/// 뒤라 iOS가 키보드를 남긴 채 화면만 바꾼다.
void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// 일과 만들기 흐름을 **통째로** 닫고 흐름에 들어오기 전 화면으로 돌아간다 (#387 D1).
///
/// 흐름은 한 장의 ShellRoute 로 루트 네비게이터에 얹혀 있다 — 그 한 장을 내리면 안의
/// 화면(입력·보상·추가 질문·카드 확인)이 함께 내려간다. 그래서 돌아가는 곳은
/// 흐름을 연 화면이다: 홈에서 만들었으면 홈, 임시저장에서 이어서 만들었으면 임시저장.
/// `context.pop()` 은 흐름 안 한 칸만 돌아간다.
///
/// 아래에 아무것도 없으면(흐름으로 곧장 들어온 경우) 보호자 홈으로 간다.
void leaveRoutineFlow(BuildContext context) {
  dismissKeyboard();
  final root = Navigator.of(context, rootNavigator: true);
  if (root.canPop()) {
    root.pop();
  } else {
    context.go(Routes.guardian);
  }
}

Future<bool> confirmLeaveRoutineFlow(
  BuildContext context, [
  RoutineLeave kind = RoutineLeave.discard,
]) async {
  final (title, message) = RoutineLeave.copyOf(kind);
  // 정말 잃을 때만 경고한다. 임시저장에 남는 나가기는 되돌릴 수 있는 동작이라
  // 경고 아이콘·노란 버튼을 쓰지 않는다 — 괜히 겁을 주면 저장된 것도 못 믿는다 (#387).
  final loses = kind == RoutineLeave.discard;
  final leave = await showElumDialog<bool>(
    context: context,
    icon: loses ? ElumDialogIcon.warning : null,
    title: title,
    message: message,
    actions: [
      // 되돌아가는 쪽을 먼저 둔다 — 실수로 누르는 일이 잦다.
      const ElumDialogAction(
        label: '계속 만들기',
        value: false,
        tone: ElumDialogTone.neutral,
      ),
      ElumDialogAction(
        label: '나가기',
        value: true,
        tone: loses ? ElumDialogTone.warn : ElumDialogTone.primary,
      ),
    ],
  );
  // 바깥을 눌러 닫으면 null이다 — 나가지 않는 쪽이 안전하다.
  return leave == true;
}

/// 흐름을 떠날 때 무엇이 남는가 (#387). 나가기 팝업의 말이 여기서 갈린다.
enum RoutineLeave {
  /// 카드 만들기 전 (입력·보상·추가 질문·준비 로딩·생성 실패) — 서버에 아무것도 없다.
  discard,

  /// 카드 만드는 중 (생성 로딩) — 나가도 생성은 서버에서 끝까지 가고, 다 되면
  /// 임시저장(`PENDING_REVIEW`)으로 남는다. 실패하면 남지 않으므로 "다 만들어지면".
  draftWhenReady,

  /// 카드 만든 뒤 (카드 확인) — 이미 임시저장에 있다.
  draft,

  /// 이미 저장한 일과를 고치는 중 (홈에서 편집으로 들어온 카드 확인). 문장·보상은
  /// 고칠 때마다 바로 저장되고, 카드 빼기만 `저장하기`를 눌러야 반영된다.
  edit;

  /// 제목과 설명. 해요체·능동·긍정형 (CLAUDE.md 말투 규칙 — `사라져요` 대신 무엇이
  /// 남는지·어디서 이어서 하는지를 말한다).
  ///
  /// 설명 줄바꿈은 손으로 둔다 — 팝업 폭(322)에서 저절로 꺾이면 `요` 한 글자만
  /// 다음 줄로 떨어진다(실제로 그랬다).
  static (String, String) copyOf(RoutineLeave kind) => switch (kind) {
    discard => ('일과 만들기를 그만둘까요?', '지금 나가면 적은 내용은 남지 않아요'),
    draftWhenReady => (
      '임시저장에 두고 나갈까요?',
      '카드가 다 만들어지면 임시저장에 남아요\n설정에서 이어서 만들 수 있어요',
    ),
    draft => ('임시저장에 두고 나갈까요?', '설정의 임시저장에서\n이어서 만들 수 있어요'),
    edit => ('저장하지 않고 나갈까요?', '뺀 카드는 저장하기를 눌러야 빠져요'),
  };
}

/// 다음 화면으로 **한 번만** 넘긴다 — 빠르게 두 번 눌러도 화면이 두 장 쌓이지 않는다.
///
/// 일과 만들기에서 다음 화면은 대개 AI 를 부르는 로딩이다(질문 준비·카드 생성).
/// 두 장 쌓이면 요청이 두 번 나가거나 검토 화면이 두 번 열린다 — 한 번이 곧 비용이다.
///
/// 풀어 주는 때는 `push` 가 돌려주는 Future 가 아니라 **이 화면이 다시 맨 위가 된
/// 순간**이다. 로딩이 다음 화면으로 교체(pushReplacement)되면 그 Future 는 끝나지
/// 않아, 돌아왔을 때 버튼이 죽어 있다 (#380).
mixin LeaveOnceMixin<T extends StatefulWidget> on State<T> {
  bool _leaving = false;

  /// 직전에 이 화면이 맨 위였는가 — 맨 위로 **돌아온 순간**을 잡는다.
  bool _wasCurrent = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (isCurrent && !_wasCurrent) _leaving = false;
    _wasCurrent = isCurrent;
  }

  /// [go]를 한 번만 부른다. 넘어간 화면이 닫혀 돌아오면 다시 부를 수 있다.
  Future<void> leaveOnce(Future<void> Function() go) async {
    if (_leaving) return;
    _leaving = true;
    await go();
  }
}
