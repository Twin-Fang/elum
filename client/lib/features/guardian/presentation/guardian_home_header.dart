import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/character_badge.dart';
import '../../../shared/models/character.dart';
import '../../notification/presentation/widgets/notification_bell_button.dart';

/// 로고 + 캐릭터 배지 + 인사말 (Figma y=70~223).
///
/// 설정은 하단 바 내정보 칸으로 옮겼다 (#798). 태블릿은 로고·이룸이 화면 입구가 옆 메뉴에 있어 인사말만 그린다.
class GuardianHomeHeader extends StatelessWidget {
  const GuardianHomeHeader({
    super.key,
    required this.childName,
    required this.character,
    required this.modeKey,
    this.part = GuardianHomeHeaderPart.all,
  });

  /// 그릴 부분. 폰은 머리 줄 + 인사말, 태블릿은 인사말만
  final GuardianHomeHeaderPart part;

  final String childName;
  final CardCharacter character;

  /// 코치마크가 캐릭터 배지를 가리킬 때 쓰는 키.
  final GlobalKey modeKey;

  /// Figma 실측 — 안전영역(59) 기준 상단 여백
  static const _top = 11.0;
  static const _logoW = 80.0;
  static const _logoH = 30.0;

  /// 머리 줄 ↔ 인사말 11 · 인사말 ↔ 부제 12
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

    final topRowChildren = <Widget>[
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
          // 종 아이콘은 배지 왼쪽. 코치마크 키는 배지에만 건다.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NotificationBellButton(),
              // 이룸이 화면으로 넘어가는 입구. 보호자→이룸이 방향은 암호 없이 바로 간다.
              // (이룸이→보호자 방향만 PIN으로 막는다)
              AppPressable(
                onTap: () => context.go(Routes.child),
                scaleDown: AppPressable.scaleIcon,
                // 그림뿐이라 이름을 주지 않으면 화면 낭독기로는 이 길을 찾을 수 없다.
                semanticLabel: context.l10n.guardianHomeGoChildScreen,
                child: KeyedSubtree(
                  key: modeKey,
                  child: CharacterBadge(character: character),
                ),
              ),
            ],
          ),
        ],
      ),
    ];
    final greetingChildren = <Widget>[
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
    ];
    final children = switch (part) {
      GuardianHomeHeaderPart.all => [...topRowChildren, ...greetingChildren],
      // 머리 줄 없이 쓰면 인사말 위 간격(11)도 뺀다
      GuardianHomeHeaderPart.greeting => greetingChildren.skip(1).toList(),
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// 머리말 중 그릴 부분
enum GuardianHomeHeaderPart {
  /// 로고 · 이룸이 화면 배지 줄 + 인사말 (폰)
  all,

  /// 인사말 · 부제만 (태블릿 — 로고·입구는 옆 메뉴)
  greeting,
}
