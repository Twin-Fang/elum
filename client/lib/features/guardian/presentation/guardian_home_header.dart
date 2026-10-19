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

/// 로고 + 캐릭터 배지 + 설정 + 인사말 (Figma y=70~223).
///
/// 셋이 y=98을 가운데로 나란히 선다. 크기가 제각각(30 · 56 · 24)이라
/// 위를 맞추면 어긋나 보인다.
class GuardianHomeHeader extends StatelessWidget {
  const GuardianHomeHeader({
    super.key,
    required this.childName,
    required this.character,
    required this.modeKey,
    this.part = GuardianHomeHeaderPart.all,
  });

  /// 그릴 부분. 가로 태블릿은 머리 줄(전폭)과 인사말(왼쪽 칸)을 따로 놓는다 (#789)
  final GuardianHomeHeaderPart part;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 이룸이 화면으로 넘어가는 입구. 보호자→이룸이 방향은 암호 없이 바로 간다.
              // (이룸이→보호자 방향만 PIN으로 막는다)
              AppPressable(
                onTap: () => context.go(Routes.child),
                scaleDown: AppPressable.scaleIcon,
                // 이룸이 화면으로 가는 유일한 입구다. 그림뿐이라 이름을 주지
                // 않으면 화면 낭독기로는 이 길을 찾을 수 없다.
                semanticLabel: context.l10n.guardianHomeGoChildScreen,
                child: KeyedSubtree(
                  key: modeKey,
                  child: CharacterBadge(character: character),
                ),
              ),
              SizedBox(width: _badgeToSettings.w),
              // 설정 진입점. 개편 시안에서 배지 오른쪽으로 옮겨졌다.
              AppPressable(
                // push로 연다. go는 스택을 교체해 설정 화면의 뒤로가기가
                // 돌아갈 곳을 잃는다 — 화살표도 기기 뒤로가기도 먹통이 된다.
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
    // 폰·세로는 한 덩어리 (시안 그대로)
    final children = switch (part) {
      GuardianHomeHeaderPart.all => [...topRowChildren, ...greetingChildren],
      GuardianHomeHeaderPart.topRow => topRowChildren,
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
  /// 머리 줄 + 인사말 (폰·세로 태블릿)
  all,

  /// 로고 · 이룸이 화면 가기 · 설정 줄만
  topRow,

  /// 인사말 · 부제만
  greeting,
}
