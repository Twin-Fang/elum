import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'elum_row_card.dart';
import 'kept_text.dart';

/// 보호자 홈 안내 카드 (알림 꺼짐 · 권유): 줄 카드 바탕 + 왼쪽 루미 타일 + 제목과 한 문장 + 오른쪽 위 닫기 x, 오른쪽 아래 알약 버튼
/// 글은 줄이지 않고 어절 단위로 줄을 바꿈 (큰 글자, 긴 번역에서도 잘리지 않게)
class HomeNoticeCard extends StatelessWidget {
  const HomeNoticeCard({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
    required this.dismissLabel,
    this.actionIconAsset,
  });

  final String title;
  final String body;
  final String actionLabel;

  /// 알약 버튼 앞 아이콘 (null 이면 글자만)
  final String? actionIconAsset;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  /// 닫기 x 낭독 글
  final String dismissLabel;

  static const _minHeight = 76.0;

  /// 루미 타일 44 (모서리 12), 그림은 타일 아래로 살짝 잘림
  static const _tileSize = 44.0;
  static const _tileRadius = 12.0;
  static const _lumiWidth = 38.0;
  static const _lumiTop = 7.0;
  static const _tileToText = 12.0;

  /// 닫기 x: 보이는 크기 10, 누름 영역 36 (카드 오른쪽 위 모서리)
  static const _closeIconSize = 10.0;
  static const _closeTapSize = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Stack(
      children: [
        ElumRowCardFrame(
          minHeight: _minHeight.h,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_tileRadius.r),
                child: Container(
                  width: _tileSize.w,
                  height: _tileSize.w,
                  color: colors.proPlanTileExtra,
                  padding: EdgeInsets.only(top: _lumiTop.w),
                  alignment: Alignment.topCenter,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: Image.asset(AppAssets.notificationsEmptyLumi, width: _lumiWidth.w, excludeFromSemantics: true),
                  ),
                ),
              ),
              SizedBox(width: _tileToText.w),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KeptText(title, style: typo.editChipLabel.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2.h),
                    KeptText(body, style: typo.bodySmall.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              // 닫기 x 가 오른쪽 위 모서리를 쓰므로 버튼은 아래쪽에 둠
              Align(
                alignment: Alignment.bottomRight,
                heightFactor: 1,
                child: Padding(
                  padding: EdgeInsets.only(top: (_closeTapSize / 2).h),
                  child: ElumRowCardChip(label: actionLabel, iconAsset: actionIconAsset, onTap: onAction),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: AppPressable(
            onTap: onDismiss,
            semanticLabel: dismissLabel,
            child: SizedBox(
              width: _closeTapSize.w,
              height: _closeTapSize.w,
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.iconClose,
                  width: _closeIconSize.w,
                  height: _closeIconSize.w,
                  excludeFromSemantics: true,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
