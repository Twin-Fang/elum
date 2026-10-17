import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/kept_text.dart';

/// 흰 카드 한 장에 [PeopleActionRow] 를 쌓음 (초대 · 그만두기). 줄 사이 선 없음
class PeopleActionCard extends StatelessWidget {
  const PeopleActionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
    // 눌림 반응이 둥근 모서리 밖으로 새지 않게 자름
    borderRadius: BorderRadius.circular(context.space.cardRadius.r),
    child: ColoredBox(
      color: context.colors.settingsGroupBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

/// 카드 안 한 줄: 제목, (선택) 보조 글, 오른쪽 꺾쇠
class PeopleActionRow extends StatelessWidget {
  const PeopleActionRow({
    super.key,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
    this.isLoading = false,
    this.startInset = defaultStartInset,
  });

  final String label;

  /// null 이면 누를 수 없음
  final VoidCallback? onTap;

  /// 제목 아래 보조 글
  final String? subtitle;

  /// 되돌릴 수 없는 줄 (위험색)
  final bool isDestructive;

  /// 이 줄이 부른 작업을 기다리는 중 (꺾쇠 자리에 스피너, 누를 수 없음)
  final bool isLoading;

  /// 글자 시작선 (카드 왼쪽 끝에서)
  final double startInset;

  static const defaultStartInset = 20.0;
  static const compactStartInset = 16.0;

  /// 시안 줄 높이는 최소값 (큰 글자에서는 줄이 늘어남)
  static const _minHeight = 56.0;
  /// 한 줄짜리는 꺾쇠(24) 높이에 맞춰 56, 보조 글이 있으면 위아래 20
  static const _padVSingleLine = 16.0;
  static const _padVWithSubtitle = 20.0;
  static const _padEnd = 16.0;
  static const _subtitleGap = 10.0;
  static const _chevronSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final subtitle = this.subtitle;
    final padV = subtitle == null ? _padVSingleLine : _padVWithSubtitle;

    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: _minHeight.h),
      child: Padding(
        padding: EdgeInsets.fromLTRB(startInset.w, padV.h, _padEnd.w, padV.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 큰 글자에서 어절 중간(`초대하` / `기`)이 아니라 띄어쓰기에서 꺾이게 함
                  KeptText(
                    label,
                    style: isDestructive
                        ? typo.peopleRowName.copyWith(color: colors.settingsDestructive)
                        : typo.settingsTileLabel.copyWith(color: colors.peopleTextPrimary, letterSpacing: 0),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: _subtitleGap.h),
                    KeptText(
                      subtitle,
                      style: typo.peopleCaption.copyWith(color: colors.peopleTextSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (isLoading)
              ElumSpinner(size: 20.w, color: colors.peopleChevron)
            else
              // 원본이 아래를 보므로 반시계 90도로 돌려 `>` 로 씀
              Transform.rotate(
                angle: -math.pi / 2,
                child: SvgPicture.asset(
                  AppAssets.iconAngleSmall,
                  width: _chevronSize.w,
                  height: _chevronSize.w,
                  colorFilter: ColorFilter.mode(colors.peopleChevron, BlendMode.srcIn),
                ),
              ),
          ],
        ),
      ),
    );

    return AppPressable(onTap: isLoading ? null : onTap, child: row);
  }
}
