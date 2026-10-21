import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

// 이야기 상세 조각: 작성 정보 줄, 보기 전환 칩, 가져오기 버튼, 도움돼요 버튼, 가져감 숫자. 배치는 talk_detail_body.dart

/// 작성 정보: 작성자 | 10/21 오후 11:42 (시안 1813:7497)
class TalkDetailPostedRow extends StatelessWidget {
  const TalkDetailPostedRow({
    super.key,
    required this.authorName,
    required this.createdAt,
  });

  final String authorName;
  final DateTime createdAt;

  /// 세로선 앞뒤 · 높이 (시안 8 · 12)
  static const _dividerGap = 8.0;
  static const _dividerHeight = 12.0;
  static const _dividerWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.typo.talkMeta.copyWith(color: colors.talkMetaText);
    final local = createdAt.toLocal();
    return Row(
      children: [
        Flexible(
          child: Text(
            authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        SizedBox(width: _dividerGap.w),
        Container(
          width: _dividerWidth,
          height: _dividerHeight.h,
          color: colors.talkMetaDivider,
        ),
        SizedBox(width: _dividerGap.w),
        Text(context.l10n.talkDetailPostedAt(local, local), style: style),
      ],
    );
  }
}

/// 보기 전환 칩: 크게 보기면 `⊞ 한 눈에 보기`, 격자면 `▢ 크게 보기` (시안 1813:7665 · 1813:7756)
class TalkDetailViewToggle extends StatelessWidget {
  const TalkDetailViewToggle({
    super.key,
    required this.isGridView,
    required this.onToggled,
  });

  final bool isGridView;
  final VoidCallback onToggled;

  /// 안쪽 · 아이콘 > 글자 (시안 16×10 · 4)
  static const _paddingH = 16.0;
  static const _paddingV = 10.0;
  static const _iconToLabel = 4.0;

  /// 아이콘 크기 (격자 12×12, 겹친 카드 10×12)
  static const _gridIconSize = 12.0;
  static const _largeIconWidth = 10.0;
  static const _largeIconHeight = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    // 지금 격자면 크게 보기로, 아니면 한 눈에 보기로 바꾸는 칩
    final icon = isGridView
        ? SvgPicture.asset(
            AppAssets.iconViewLarge,
            width: _largeIconWidth.w,
            height: _largeIconHeight.w,
          )
        : SvgPicture.asset(
            AppAssets.iconViewGrid,
            width: _gridIconSize.w,
            height: _gridIconSize.w,
            colorFilter: ColorFilter.mode(colors.talkTitleText, BlendMode.srcIn),
          );
    return AppPressable(
      onTap: onToggled,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _paddingH.w,
          vertical: _paddingV.h,
        ),
        decoration: BoxDecoration(
          color: colors.editChipBg,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(width: _iconToLabel.w),
            Text(
              isGridView ? l10n.talkViewLarge : l10n.talkViewGrid,
              style: context.typo.chipLabel.copyWith(
                color: colors.talkTitleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 아래 `⬇ 일과로 가져오기` (360×66, 반지름 18, 시안 1813:7658)
/// 이미 가져온 글은 `✓ 일과관리에 넣었어요` (다시 누르면 한 번 더 넣는다)
class TalkDetailImportButton extends StatelessWidget {
  const TalkDetailImportButton({
    super.key,
    required this.isImported,
    required this.onPressed,
  });

  final bool isImported;
  final VoidCallback onPressed;

  /// 아이콘 한 변 · 아이콘 > 글자 (시안 20 · 10)
  static const _iconSize = 20.0;
  static const _iconToLabel = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final labelStyle = context.typo.talkImportLabel.copyWith(
      color: colors.buttonEnabledText,
    );
    return AppPressable(
      onTap: onPressed,
      child: Container(
        height: space.buttonH.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.buttonEnabled,
          borderRadius: BorderRadius.circular(space.buttonRadius.r),
        ),
        child: isImported
            ? Text(l10n.talkImportedButton, style: labelStyle)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 가져감 아이콘과 같은 `fi-br-download`
                  SvgPicture.asset(
                    AppAssets.iconDownload,
                    width: _iconSize.w,
                    height: _iconSize.w,
                    colorFilter: ColorFilter.mode(
                      colors.buttonEnabledText,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: _iconToLabel.w),
                  Text(l10n.talkImportButton, style: labelStyle),
                ],
              ),
      ),
    );
  }
}

/// 도움돼요 칩 (시안 1813:7881): 누르면 켜지고 다시 누르면 꺼진다
/// 꺼짐은 시안 값(웜그레이 판 · 연회색 아이콘), 켜짐은 시안에 없어 민트 판 · 테두리 · 아이콘으로 구분
class TalkHelpfulButton extends StatelessWidget {
  const TalkHelpfulButton({
    super.key,
    required this.count,
    required this.isSelected,
    required this.onPressed,
  });

  final int count;
  final bool isSelected;
  final VoidCallback onPressed;

  /// 시안: 아이콘 20, 좌우 16 · 위아래 10, 높이 40 알약(모서리 20), 아이콘 > 글자 4
  static const _iconSize = 20.0;
  static const _paddingH = 16.0;
  static const _paddingV = 10.0;
  static const _radius = 20.0;
  static const _iconToLabel = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Semantics(
      selected: isSelected,
      button: true,
      child: AppPressable(
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _paddingH.w,
            vertical: _paddingV.h,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.goalSelectedFill : colors.editChipBg,
            borderRadius: BorderRadius.circular(_radius.r),
          ),
          // 테두리는 위에 그려 켜고 꺼도 칩 크기 그대로 (아래 줄이 밀리지 않게)
          foregroundDecoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius.r),
                  border: Border.all(
                    color: colors.goalSelectedBorder,
                    width: space.selectedBorderWidth,
                  ),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                AppAssets.iconThumbsUp,
                width: _iconSize.w,
                height: _iconSize.w,
                colorFilter: ColorFilter.mode(
                  isSelected ? colors.goalSelectedBorder : colors.talkMetaIcon,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: _iconToLabel.w),
              Text(
                context.l10n.talkHelpfulCount(count),
                style: context.typo.talkDetailStatLabel.copyWith(
                  color: isSelected ? colors.textPrimary : colors.talkMetaText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 가져감 숫자 (시안 1813:7861): 다운로드 아이콘 16 + 숫자. 누르는 칸이 아니다
/// 읽기 프로그램에는 `3명 가져감` 처럼 이름과 함께 읽힌다
class TalkImportCountLabel extends StatelessWidget {
  const TalkImportCountLabel({super.key, required this.count});

  final int count;

  /// 시안: 아이콘 16, 아이콘 > 숫자 4
  static const _iconSize = 16.0;
  static const _iconToCount = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: context.l10n.talkPopularImportCount(count),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppAssets.iconDownload,
            width: _iconSize.w,
            height: _iconSize.w,
            colorFilter: ColorFilter.mode(colors.talkMetaIcon, BlendMode.srcIn),
          ),
          SizedBox(width: _iconToCount.w),
          Text(
            '$count',
            style: context.typo.talkDetailStatLabel.copyWith(
              color: colors.talkMetaText,
            ),
          ),
        ],
      ),
    );
  }
}
