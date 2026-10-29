import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_centered_title_row.dart';

/// 이야기 하위 화면 머리 줄 (시안 1783:7473 · 1860:8458): 뒤로 | 가운데 제목 | (있으면) 신고 깃발 또는 ⋯ · 공유
/// 공유가 있으면 양옆 칸을 오른쪽 상자 두 개 폭으로 넓혀 제목을 가운데에 둔다. 깃발 x 313 · 공유 x 349 (아이콘 20, 사이 16)
/// 뒤로가기 상자 40×40 이 x=16, y=67 (상태 표시줄 포함 화면 위 기준) — 다른 하위 화면(`ElumScaffold backTop: 67`)과 같은 자리
/// SafeArea 밖에서 쓴다: 상태 표시줄 높이를 직접 빼서 시안 y 를 맞춘다
class TalkTopBar extends StatelessWidget {
  const TalkTopBar({
    super.key,
    required this.title,
    required this.onBackPressed,
    this.onMorePressed,
    this.isMoreVisible = false,
    this.shouldShowReportIcon = false,
    this.onSharePressed,
  });

  final String title;
  final VoidCallback onBackPressed;

  /// ⋯ 를 눌렀을 때. null 이면 자리만 두고 그리지 않는다
  final VoidCallback? onMorePressed;

  /// ⋯ 자리를 둘지 (글을 받기 전에는 자리만 비워 제목이 흔들리지 않게)
  final bool isMoreVisible;

  /// 메뉴 버튼을 ⋯ 대신 신고 깃발로 그릴지 (남의 글: 신고 · 숨기기 메뉴)
  final bool shouldShowReportIcon;

  /// 공유를 눌렀을 때 (아이콘 상자 영역 > 아이패드 공유 시트 팝오버 기준). null 이면 공유 없음
  final ValueChanged<Rect?>? onSharePressed;

  /// 시안 실측: 뒤로가기 상자 y 67 · 상자 40 · 좌우 16 · 상자 아래 본문까지 12 (상세 본문 첫 칩 위치를 #939 실측 그대로 둠)
  static const _boxTop = 67.0;
  static const _boxSize = 40.0;
  static const _sideInset = 16.0;
  static const _iconSize = 24.0;

  /// 오른쪽 아이콘 상자: 20 아이콘 사이 16 을 시안대로 두려고 뒤로가기(40)보다 좁힌다
  static const _trailingBoxSize = 36.0;

  /// 신고 깃발 · 공유 아이콘 (시안 fi-br-flag · fi-br-upload 20×20)
  static const _trailingIconSize = 20.0;
  static const _bottomGap = 12.0;

  /// 화면 위에서 본문이 시작하는 시안 y (상자 아래 + 간격)
  static const contentTop = _boxTop + _boxSize + _bottomGap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final safeTop = MediaQuery.paddingOf(context).top;
    // 시안 y 는 상태 표시줄을 포함한 값 > 상태 표시줄을 빼고 남은 만큼만 띄운다
    final topGap = (_boxTop.h - safeTop).clamp(0.0, _boxTop.h);
    final onMorePressed = this.onMorePressed;
    final onSharePressed = this.onSharePressed;
    final isMoreShown = isMoreVisible && onMorePressed != null;
    // 공유 화면(상세)은 오른쪽 상자 두 개, 그 밖은 뒤로가기 상자 하나
    final sideSlotWidth = onSharePressed != null
        ? _trailingBoxSize.w * 2
        : _boxSize.w;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _sideInset.w,
        safeTop + topGap,
        _sideInset.w,
        _bottomGap.h,
      ),
      child: ElumCenteredTitleRow(
        sideSlotWidth: sideSlotWidth,
        title: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typo.navTitle.copyWith(color: colors.textPrimary),
        ),
        // 칸이 상자보다 넓을 수 있어 왼쪽에 붙인다
        leading: Align(
          alignment: Alignment.centerLeft,
          child: _IconBox(
            asset: AppAssets.iconBack,
            semanticLabel: l10n.commonBack,
            color: null,
            onTap: (_) => onBackPressed(),
          ),
        ),
        trailing: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isMoreShown && shouldShowReportIcon)
              _IconBox(
                asset: AppAssets.iconFlag,
                semanticLabel: l10n.talkMenuReport,
                color: colors.talkMetaText,
                boxSize: _trailingBoxSize,
                iconSize: _trailingIconSize,
                onTap: (_) => onMorePressed(),
              )
            else if (isMoreShown)
              _IconBox(
                asset: AppAssets.iconMenuDots,
                semanticLabel: l10n.talkMoreLabel,
                color: colors.textPrimary,
                boxSize: _trailingBoxSize,
                onTap: (_) => onMorePressed(),
              ),
            if (onSharePressed != null)
              _IconBox(
                asset: AppAssets.iconShare,
                semanticLabel: l10n.talkShareLinkButton,
                color: colors.talkMetaText,
                boxSize: _trailingBoxSize,
                iconSize: _trailingIconSize,
                onTap: onSharePressed,
              ),
          ],
        ),
      ),
    );
  }
}

/// 누름 상자(기본 40×40) 가운데 아이콘 (기본 24). 누르면 상자 영역을 넘긴다 (공유 팝오버 기준)
class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.asset,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
    this.boxSize = TalkTopBar._boxSize,
    this.iconSize = TalkTopBar._iconSize,
  });

  final String asset;
  final String semanticLabel;

  /// null 이면 SVG 원래 색 (뒤로가기)
  final Color? color;
  final ValueChanged<Rect?> onTap;
  final double boxSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: AppPressable(
        onTap: () => onTap(_globalRectOf(context)),
        scaleDown: AppPressable.scaleIcon,
        child: SizedBox(
          width: boxSize.w,
          height: boxSize.w,
          child: Center(
            child: SvgPicture.asset(
              asset,
              width: iconSize.w,
              height: iconSize.w,
              excludeFromSemantics: true,
              colorFilter: color == null
                  ? null
                  : ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  // 화면 기준 상자 영역 (아직 그려지기 전이면 null)
  static Rect? _globalRectOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// 댓글 줄 ⋯ (아이콘 18, 연회색). 누름 영역은 44 로 넓힌다
class TalkMoreDotsButton extends StatelessWidget {
  const TalkMoreDotsButton({super.key, required this.onTap});

  final VoidCallback onTap;

  static const _iconSize = 18.0;
  static const _tapSize = 44.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.talkMoreLabel,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleIcon,
        child: SizedBox(
          width: _tapSize.w,
          height: _tapSize.w,
          child: Center(
            child: SvgPicture.asset(
              AppAssets.iconMenuDots,
              width: _iconSize.w,
              height: _iconSize.w,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(
                context.colors.talkMetaIcon,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
