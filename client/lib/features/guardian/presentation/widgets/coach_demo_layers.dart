import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import 'coach_demo_content.dart';
import 'coach_demo_parts.dart';
import 'library_routine_tile.dart';

/// 일과관리 코치마크 시범 연출. 구멍 위에 얹혀 **그림만** 그린다 (터치·서버·일과 데이터는 건드리지 않음)
///
/// 모두 `CoachMarkStep.demoBuilder` 에 꽂을 수 있게 [Positioned] 를 돌려준다.
/// 한 주기는 [AppMotion.coachDemoLoop]. 동작 줄이기면 멈춘 마지막 장면만 그린다.

/// 보낸 뒤 토스트: 화면 바닥에서 띄우는 거리 (진행 점·안내 문구 위)
const _toastBottomInset = 190.0;

/// 누르기: 칸 탭 > 상세 시트(카드 고치기 | 오늘 보내기)가 올라옴
Widget tapDemo(BuildContext context, Rect target) => buildCoachDemoLoop(
  endScene: 0.7,
  builder: (context, t) => Stack(
    children: [
      CoachDemoPreviewSheet(
        slide: coachDemoPhase(t, 0.3, 0.45),
        child: const CoachDemoSheetButtons(),
      ),
      CoachDemoFinger(
        center: target.center,
        press: coachDemoPulse(t, 0.1, 0.25),
        appear: coachDemoPhase(t, 0, 0.1) * (1 - coachDemoPhase(t, 0.35, 0.45)),
      ),
      CoachDemoRing(
        center: target.center,
        spread: coachDemoPhase(t, 0.17, 0.35),
      ),
    ],
  ),
);

/// 길게 누르기: 칸 꾹 + 링이 퍼짐 (실제 메뉴는 칸 옆에 뜨는데 말풍선 글자를 가려서 그리지 않는다)
Widget longPressDemo(BuildContext context, Rect target) => buildCoachDemoLoop(
  endScene: 0.5,
  builder: (context, t) => Stack(
    children: [
      CoachDemoFinger(
        center: target.center,
        press: coachDemoPhase(t, 0.1, 0.2) * (1 - coachDemoPhase(t, 0.6, 0.7)),
        appear: coachDemoPhase(t, 0, 0.1) * (1 - coachDemoPhase(t, 0.65, 0.75)),
      ),
      CoachDemoRing(center: target.center, spread: coachDemoPhase(t, 0.2, 0.6)),
    ],
  ),
);

/// 보낸 뒤: ✓ 배지가 칸에 톡 붙고 실제 토스트 문구가 뜸
Widget sentBadgeDemo(
  BuildContext context,
  Rect target, {
  required String routineTitle,
}) => buildCoachDemoLoop(
  endScene: 0.85,
  builder: (context, t) {
    // 실제 칸: 그림 칸이 가운데 위에 있고, ✓ 는 그 오른쪽 아래 모서리에서 xs/2 만큼 삐져나온다
    final iconSize = LibraryRoutineTile.iconSize.w;
    final badgeSize = LibraryRoutineTile.badgeSize.w;
    final overhang = context.space.xs.w / 2;
    final iconRight = target.center.dx + iconSize / 2;
    final iconBottom = target.top + iconSize;
    return Stack(
      children: [
        Positioned(
          left: iconRight + overhang - badgeSize,
          top: iconBottom + overhang - badgeSize,
          child: Transform.scale(
            scale: Curves.elasticOut.transform(coachDemoPhase(t, 0.15, 0.4)),
            child: LibrarySentBadge(size: badgeSize),
          ),
        ),
        // 실제 알림처럼 화면 아래쪽에 뜬다 (위쪽은 말풍선 자리)
        Positioned(
          left: 0,
          right: 0,
          bottom: _toastBottomInset.h,
          child: Opacity(
            opacity:
                coachDemoPhase(t, 0.35, 0.5) * (1 - coachDemoPhase(t, 0.9, 1)),
            child: Center(
              child: CoachDemoToast(
                text: context.l10n.routineLibrarySent(routineTitle),
              ),
            ),
          ),
        ),
      ],
    );
  },
);

/// 끌어서 묶기: 첫 칸 그림을 들어 올려 둘째 칸 위로 > 놓으면 그 자리에 묶음 칸이 생김
///
/// [ghost] 는 끌려가는 그림 칸에 들어갈 내용 (연습 무대는 예시 일과 그림을 넘긴다). 없으면 빈 칸.
Widget dragToGroupDemo(
  BuildContext context,
  Rect first,
  Rect second, {
  Widget? ghost,
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
            child: Opacity(opacity: drop, child: const CoachDemoGroupPreview()),
          ),
        ),
        CoachDemoFinger(
          center: moving.center,
          press: lift * (1 - drop),
          appear:
              coachDemoPhase(t, 0, 0.1) * (1 - coachDemoPhase(t, 0.65, 0.75)),
        ),
      ],
    );
  },
);

/// 버튼으로 묶기: + 일과 만들기 탭 (시트는 올리지 않는다: 말풍선과 안내 문구를 가린다)
Widget createGroupDemo(BuildContext context, Rect target) => buildCoachDemoLoop(
  endScene: 0.5,
  builder: (context, t) => Stack(
    children: [
      CoachDemoFinger(
        center: target.center,
        press: coachDemoPulse(t, 0.1, 0.25),
        appear: coachDemoPhase(t, 0, 0.1) * (1 - coachDemoPhase(t, 0.6, 0.7)),
      ),
      CoachDemoRing(
        center: target.center,
        spread: coachDemoPhase(t, 0.17, 0.5),
      ),
    ],
  ),
);
