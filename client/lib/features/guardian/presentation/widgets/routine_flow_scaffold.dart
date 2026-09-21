import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/app_pressable.dart';
import 'aurora_background.dart';

/// 일과 만들기 흐름의 공통 뼈대.
///
/// 네 화면(입력·로딩·추가질문·카드확인)이 같은 배경과 상단 버튼을 공유한다.
/// 화면마다 반복하면 배경이 조금씩 어긋나고, 무엇보다 [AuroraBackground]가
/// 화면 전환마다 재생성되어 애니메이션이 튄다.
///
/// Figma는 뒤로가기(x=24)와 홈(x=72)을 나란히 둔다. 홈은 흐름을 중간에
/// 빠져나가는 길이다 — 일과 만들기는 단계가 길어 되돌아갈 방법이 필요하다.
class RoutineFlowScaffold extends StatelessWidget {
  const RoutineFlowScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.bottomButton,
    this.showAurora = true,
    this.confirmExit = false,
  });

  final Widget child;

  /// null이면 뒤로가기를 그리지 않는다 (되돌릴 수 없는 단계)
  final VoidCallback? onBack;

  /// 하단 고정 CTA. 입력·로딩 화면에는 없다.
  final Widget? bottomButton;

  /// 배경 글로우를 그릴지. **Figma에 Gradient가 없는 화면은 false로 끈다.**
  ///
  /// 글로우는 입력 화면(238:1643의 Gradient 238:1728)을 재현한 것이라
  /// 모든 화면에 있는 배경이 아니다. 카드확인(262:5124)은 단색 배경뿐이다.
  /// 기본값을 true로 둬 이미 맞는 화면들이 영향받지 않게 한다.
  final bool showAurora;

  /// 나가기 전에 물어볼지 (이슈 #242).
  ///
  /// **일과를 만들다 중간에 나가면 되돌릴 수 없다.** 입력한 문장도, AI가 만든
  /// 카드도 사라지는데 카드 생성은 30초 넘게 걸린다 — 잘못 눌러 날리면 그 시간을
  /// 다시 쓴다.
  ///
  /// 뒤로가기·홈·**시스템 뒤로가기(제스처)** 를 모두 잡는다. 화면 안의 버튼만
  /// 막으면 제스처로 그냥 빠져나간다.
  ///
  /// 잃을 것이 없는 화면에서는 false로 둔다 — 물어볼 것이 없는데 묻는 팝업이
  /// 가장 성가시다.
  final bool confirmExit;

  /// 나가도 되는지 묻는다. 물어보지 않기로 했으면 그대로 통과시킨다.
  Future<bool> _mayLeave(BuildContext context) async =>
      confirmExit ? confirmLeaveRoutineFlow(context) : true;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return PopScope(
      // 시스템 뒤로가기(제스처·버튼)를 여기서 잡는다.
      canPop: !confirmExit,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _mayLeave(context);
        if (!ok || !context.mounted) return;
        dismissKeyboard();
        context.pop();
      },
      child: _scaffold(context, space),
    );
  }

  Widget _scaffold(BuildContext context, AppSpacing space) {
    return Scaffold(
      backgroundColor: context.colors.background,
      // 키보드가 올라와도 배경이 밀려 찌그러지지 않게 한다
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (showAurora) const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onBack: onBack == null
                      ? null
                      : () async {
                          if (!await _mayLeave(context)) return;
                          dismissKeyboard();
                          onBack!();
                        },
                  onHome: () async {
                    final ok = await _mayLeave(context);
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
                      space.lg,
                    ),
                    child: bottomButton,
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

Future<bool> confirmLeaveRoutineFlow(BuildContext context) async {
  final leave = await showElumDialog<bool>(
    context: context,
    icon: ElumDialogIcon.warning,
    title: '만들던 일과가 사라져요',
    actions: const [
      // 되돌아가는 쪽을 먼저 둔다 — 실수로 누르는 일이 잦다.
      ElumDialogAction(
        label: '계속 만들기',
        value: false,
        tone: ElumDialogTone.neutral,
      ),
      ElumDialogAction(
        label: '나가기',
        value: true,
        tone: ElumDialogTone.warn,
      ),
    ],
  );
  // 바깥을 눌러 닫으면 null이다 — 나가지 않는 쪽이 안전하다.
  return leave == true;
}
