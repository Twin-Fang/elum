import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/coach_mark_overlay.dart';
import '../../../../core/widgets/coach_mark_parts.dart';
import 'coach_demo_content.dart';
import 'coach_demo_parts.dart';
import 'library_routine_tile.dart';
import 'routine_sent_toast.dart';

/// 일과관리 코치마크 시범 연출. 구멍 위에 얹혀 **그림만** 그린다 (터치·서버·일과 데이터는 건드리지 않음)
///
/// 모두 `CoachMarkStep.demoBuilder` 에 꽂을 수 있게 [Positioned] 를 돌려준다.
/// 한 주기는 [AppMotion.coachDemoLoop]. 동작 줄이기면 멈춘 마지막 장면만 그린다.

/// 누르기: 대상 모양 그대로 눌렸다가 번짐 (시트는 올리지 않는다: 어두운 막 위에 밝은 시트만 튀어 보인다)
Widget tapDemo(BuildContext context, CoachHole hole) => buildCoachDemoLoop(
  endScene: _tapPeak,
  builder: (context, t) => _tapPress(hole, t),
);

/// 누르기 한 번의 눌림 꼭대기 (동작 줄이기 멈춤 장면: 대상 테두리가 또렷한 순간)
const _tapPeak = 0.15;

/// 누르기 한 번: 0.05~0.25 눌렀다 뗌, 0.12~0.45 번짐
Widget _tapPress(CoachHole hole, double t) => CoachDemoPressOutline(
  rect: hole.rect,
  radius: hole.radius,
  press: coachDemoPulse(t, 0.05, 0.25),
  ripple: coachDemoPhase(t, 0.12, 0.45),
);

/// 예약: 누른 뒤 도구 겉면이 고른 반복 요약(`평일 오전 8:00`)으로 바뀌어 머묾 > 끝에 되돌아감
///
/// [pickedFace] 는 요약이 적힌 도구 겉면 (실제 도구와 같은 부품)
Widget scheduleTapDemo(
  BuildContext context,
  CoachHole hole, {
  required Widget pickedFace,
}) => buildCoachDemoLoop(
  endScene: 0.6,
  builder: (context, t) {
    final appear = coachDemoPhase(t, 0.3, 0.4) * (1 - coachDemoPhase(t, 0.9, 1));
    return Stack(
      children: [
        Positioned.fromRect(
          rect: hole.rect,
          child: Opacity(
            opacity: appear,
            child: Transform.scale(
              scale: 0.92 + 0.08 * AppMotion.springPop.transform(appear),
              child: pickedFace,
            ),
          ),
        ),
        _tapPress(hole, t),
      ],
    );
  },
);

/// 저장: 누른 뒤 버튼 오른쪽 안에 보내기 체크(보낸 뒤 토스트와 같은 그림)가 톡 튀어나와 머묾
Widget sendTapDemo(BuildContext context, CoachHole hole) => buildCoachDemoLoop(
  endScene: 0.6,
  builder: (context, t) {
    final checkSize = _sentCheckSize.w;
    final isCheckShown = t >= 0.3 && t < 0.9;
    return Stack(
      children: [
        _tapPress(hole, t),
        // 이름은 가운데라 오른쪽 안쪽에 둠 (버튼 밖·화면 끝으로 나가지 않음)
        if (isCheckShown)
          Positioned(
            left: hole.rect.right - context.space.md.w - checkSize,
            top: hole.rect.center.dy - checkSize / 2,
            child: ClipOval(
              child: SizedBox.square(
                dimension: checkSize,
                child: const RoutineSentCheck(),
              ),
            ),
          ),
      ],
    );
  },
);

/// 보내기 체크 판 지름 (토스트 앞 판과 같은 38)
const _sentCheckSize = 38.0;

/// 길게 눌렀다 떼기: 꾹 누르면 대상 모양이 번지고, 손을 떼면 칸 옆에 메뉴가 뜬다 (끌지 않으면 메뉴)
///
/// 메뉴는 칸 카드 오른쪽 끝에서 띄운다. 화면 오른쪽 끝을 넘으면 칸 왼쪽으로 돌린다.
Widget longPressDemo(BuildContext context, CoachHole hole) => buildCoachDemoLoop(
  endScene: 0.85,
  builder: (context, t) {
    final target = hole.rect;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final menuWidth = CoachDemoAnchoredMenu.width.w;
    final gap = context.space.sm.w;
    final isRoomOnRight = target.right + gap + menuWidth <= screenWidth - gap;
    final menuLeft = isRoomOnRight
        ? target.right + gap
        : target.left - gap - menuWidth;
    // 칸 위 끝에 맞추되, 아래 점·안내 문구 자리는 넘지 않게 올린다
    final media = MediaQuery.of(context);
    final menuHeight =
        CoachDemoAnchoredMenu.rowHeight.h * CoachDemoAnchoredMenu.rowCount;
    final menuBottomLimit =
        media.size.height -
        media.padding.bottom -
        CoachMarkOverlay.bottomReserve.h;
    final menuTop = target.top.clamp(
      media.padding.top,
      (menuBottomLimit - menuHeight).clamp(media.padding.top, double.infinity),
    );
    // 메뉴를 일찍 띄워 오래 둔다: 말풍선 화살표가 메뉴 아래 끝에 붙어 있다
    final appear = coachDemoPhase(t, 0.3, 0.38);
    return Stack(
      children: [
        // 꾹 누름: 눌린 채 머물다 0.25~0.3 에 뗌
        CoachDemoPressOutline(
          rect: target,
          radius: hole.radius,
          press:
              coachDemoPhase(t, 0.05, 0.15) * (1 - coachDemoPhase(t, 0.25, 0.3)),
          ripple: coachDemoPhase(t, 0.1, 0.28),
        ),
        Positioned(
          left: menuLeft,
          top: menuTop,
          child: Opacity(
            opacity: appear,
            child: Transform.scale(
              scale: 0.92 + 0.08 * appear,
              alignment: isRoomOnRight ? Alignment.topLeft : Alignment.topRight,
              child: const CoachDemoAnchoredMenu(),
            ),
          ),
        ),
      ],
    );
  },
);

/// 끌어서 묶기: 첫 칸 그림을 들어 올려 둘째 칸 위로 > 놓으면 그 자리에 묶음 칸이 생김
///
/// [ghost] 는 끌려가는 그림 칸 내용, [groupItems] 는 놓은 뒤 묶음 칸 안 그림 (안내 무대는 예시 일과 그림). 없으면 빈 칸.
Widget dragToGroupDemo(
  BuildContext context,
  Rect first,
  Rect second, {
  Widget? ghost,
  List<Widget> groupItems = const [],
}) => buildCoachDemoLoop(
  endScene: 0.8,
  builder: (context, t) {
    final move = Curves.easeInOut.transform(coachDemoPhase(t, 0.25, 0.6));
    final lift = coachDemoPhase(t, 0.15, 0.25);
    final drop = coachDemoPhase(t, 0.6, 0.7);
    // 칸 전체가 아니라 실제 칸의 그림 자리(가운데 위)만 움직인다
    final iconSize = LibraryRoutineTile.iconSize.w;
    Rect iconOf(Rect cell) => Rect.fromLTWH(
      cell.center.dx - iconSize / 2,
      cell.top,
      iconSize,
      iconSize,
    );
    final from = iconOf(first);
    final to = iconOf(second);
    final moving = Rect.lerp(from, to, move)!;
    final colors = context.colors;
    final radius = BorderRadius.circular(LibraryRoutineTile.iconRadius.w);
    return Stack(
      children: [
        // 받는 칸: 위에 올라오면 테두리가 뜨며 살짝 커짐
        Positioned.fromRect(
          rect: to,
          child: Transform.scale(
            scale: 1 + 0.1 * coachDemoPhase(t, 0.5, 0.6) * (1 - drop),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: colors.surface.withValues(
                    alpha: coachDemoPhase(t, 0.45, 0.55) * (1 - drop),
                  ),
                  width: 2.w,
                ),
              ),
            ),
          ),
        ),
        // 끌려가는 그림 칸
        Positioned.fromRect(
          rect: moving,
          child: Transform.scale(
            scale: 1 + 0.12 * lift - 0.4 * drop,
            child: Opacity(
              opacity: 1 - drop,
              child: CoachDemoGhostTile(
                color: colors.surface,
                opacity: 1,
                child: ghost,
              ),
            ),
          ),
        ),
        // 놓은 자리에 묶음 칸: 2×2 미리보기
        Positioned.fromRect(
          rect: to,
          child: Transform.scale(
            scale: Curves.easeOutBack.transform(drop),
            child: Opacity(
              opacity: drop,
              child: CoachDemoGroupPreview(items: groupItems),
            ),
          ),
        ),
        // 잡은 그림 칸 테두리 (칸과 같은 모서리, 놓으면 사라짐)
        CoachDemoPressOutline(
          rect: Rect.fromCenter(
            center: moving.center,
            width: moving.width * (1 + 0.12 * lift),
            height: moving.height * (1 + 0.12 * lift),
          ),
          radius: LibraryRoutineTile.iconRadius.w,
          press: lift * (1 - drop),
        ),
      ],
    );
  },
);
