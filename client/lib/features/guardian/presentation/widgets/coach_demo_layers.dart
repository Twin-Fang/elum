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

/// 누르기: 칸 탭 > 상세 시트(카드 고치기 | 오늘 보내기)가 올라옴
Widget tapDemo(BuildContext context, Rect target) => coachDemoLoop(
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

/// 길게 누르기: 칸 꾹 > 링이 퍼짐 > 빠른 메뉴 시트가 올라옴
Widget longPressDemo(BuildContext context, Rect target) => coachDemoLoop(
  endScene: 0.8,
  builder: (context, t) => Stack(
    children: [
      CoachDemoPreviewSheet(
        slide: coachDemoPhase(t, 0.5, 0.65),
        child: const CoachDemoMenuRows(),
      ),
      CoachDemoFinger(
        center: target.center,
        press: coachDemoPhase(t, 0.1, 0.2) * (1 - coachDemoPhase(t, 0.5, 0.55)),
        appear: coachDemoPhase(t, 0, 0.1) * (1 - coachDemoPhase(t, 0.55, 0.65)),
      ),
      CoachDemoRing(center: target.center, spread: coachDemoPhase(t, 0.2, 0.5)),
    ],
  ),
);

/// 보낸 뒤: ✓ 배지가 칸에 톡 붙고 실제 토스트 문구가 뜸
Widget sentBadgeDemo(
  BuildContext context,
  Rect target, {
  required String routineTitle,
}) => coachDemoLoop(
  endScene: 0.85,
  builder: (context, t) {
    final badgeSize = 20.w;
    return Stack(
      children: [
        Positioned(
          left: target.right - badgeSize * 0.8,
          top: target.top + target.width * 0.78,
          child: Transform.scale(
            scale: Curves.elasticOut.transform(coachDemoPhase(t, 0.15, 0.4)),
            child: LibrarySentBadge(size: badgeSize),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: target.bottom + 12.h,
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

/// 끌어서 묶기: 첫 칸을 들어 올려 둘째 칸 위로 > 놓으면 묶음 칸이 생김
Widget dragToGroupDemo(
  BuildContext context,
  Rect first,
  Rect second,
) => coachDemoLoop(
  endScene: 0.8,
  builder: (context, t) {
    final move = Curves.easeInOut.transform(coachDemoPhase(t, 0.25, 0.6));
    final lift = coachDemoPhase(t, 0.15, 0.25);
    final drop = coachDemoPhase(t, 0.6, 0.7);
    final ghost = Rect.lerp(first, second, move)!;
    final colors = context.colors;
    return Stack(
      children: [
        // 받는 칸: 위에 올라오면 살짝 커짐
        Positioned.fromRect(
          rect: second,
          child: Transform.scale(
            scale: 1 + 0.1 * coachDemoPhase(t, 0.5, 0.6) * (1 - drop),
            child: CoachDemoGhostTile(color: colors.surface, opacity: 1 - drop),
          ),
        ),
        // 끌려가는 칸
        Positioned.fromRect(
          rect: ghost,
          child: Transform.scale(
            scale: 1 + 0.15 * lift - 0.4 * drop,
            child: CoachDemoGhostTile(color: colors.surface, opacity: 1 - drop),
          ),
        ),
        // 놓은 자리에 묶음 칸: 2×2 미리보기
        Positioned.fromRect(
          rect: second,
          child: Transform.scale(
            scale: Curves.easeOutBack.transform(drop),
            child: Opacity(opacity: drop, child: const CoachDemoGroupPreview()),
          ),
        ),
        CoachDemoFinger(
          center: ghost.center,
          press: lift * (1 - drop),
          appear:
              coachDemoPhase(t, 0, 0.1) * (1 - coachDemoPhase(t, 0.65, 0.75)),
        ),
      ],
    );
  },
);

/// 버튼으로 묶기: + 일과 만들기 탭 > "무엇을 만들까요?" 시트에서 새 묶음 만들기
Widget createGroupDemo(BuildContext context, Rect target) => coachDemoLoop(
  endScene: 0.7,
  builder: (context, t) => Stack(
    children: [
      CoachDemoPreviewSheet(
        slide: coachDemoPhase(t, 0.3, 0.45),
        child: const CoachDemoCreateChoices(),
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
