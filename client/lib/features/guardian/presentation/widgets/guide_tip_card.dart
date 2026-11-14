import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/tap_haptics.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_row_card.dart';
import '../../../../core/widgets/home_notice_card.dart';
import '../../../../core/widgets/kept_text.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/utils/open_notice_link.dart';
import '../../application/guide_tip_controller.dart';
import '../../domain/guide_tip.dart';

/// 안내 글을 열지 못했을 때 실패 팝업 코드
const guideTipOpenFailedCode = 'E-GUIDE-LINK';

/// 보호자 화면 가이드 팁 자리: 자리별 안 닫은 첫 팁 하나 > 누르면 사이트 안내 글(외부 브라우저), x 면 영구 숨김
/// 닫으면 접히며 사라짐. 팁이 없으면 빈 자리 (여백 포함)
class GuideTipSlot extends ConsumerWidget {
  const GuideTipSlot({
    super.key,
    required this.placement,
    this.padding = EdgeInsets.zero,
    this.isSuppressed = false,
  });

  final GuideTipPlacement placement;

  /// 팁이 보일 때만 두는 바깥 여백
  final EdgeInsets padding;

  /// 같은 화면에 다른 안내 카드가 떠 있어 잠시 숨김 (닫은 기록은 안 남김)
  final bool isSuppressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = ref.watch(guideTipForPlacementProvider(placement));
    return HomeNoticeSwitcher(
      child: tip == null || isSuppressed
          ? null
          : Padding(
              key: ValueKey(tip),
              padding: padding,
              child: GuideTipCard(
                pictureAsset: _pictureAssetOf(tip),
                title: _titleOf(tip, context.l10n),
                body: _bodyOf(tip, context.l10n),
                dismissLabel: context.l10n.guideTipDismissLabel,
                onTap: () => _openArticle(context, tip),
                onDismiss: () => ref.read(dismissedGuideTipsProvider.notifier).dismiss(tip),
              ),
            ),
    );
  }

  // 외부 브라우저로 열기, 못 열면 실패 팝업 + 코드
  Future<void> _openArticle(BuildContext context, GuideTip tip) async {
    final url = toGuideArticleUrl(tip, context.appLocale.languageCode);
    final isOpened = await openNoticeLink(url);
    if (isOpened || !context.mounted) return;
    await showFailureMessage(context, sentence: context.l10n.guideTipOpenFailed, code: guideTipOpenFailedCode);
  }

  static String _pictureAssetOf(GuideTip tip) => switch (tip) {
    GuideTip.actionCards || GuideTip.makeActionCards => AppAssets.guideTipPictureCard,
    GuideTip.caregiverRole => AppAssets.guideTipHelpingHand,
    GuideTip.taskAnalysis => AppAssets.guideTipSteps,
    GuideTip.rewards => AppAssets.guideTipReward,
  };

  static String _titleOf(GuideTip tip, AppLocalizations l10n) => switch (tip) {
    GuideTip.actionCards => l10n.guideTipActionCardsTitle,
    GuideTip.makeActionCards => l10n.guideTipMakeActionCardsTitle,
    GuideTip.caregiverRole => l10n.guideTipCaregiverRoleTitle,
    GuideTip.taskAnalysis => l10n.guideTipTaskAnalysisTitle,
    GuideTip.rewards => l10n.guideTipRewardsTitle,
  };

  static String _bodyOf(GuideTip tip, AppLocalizations l10n) => switch (tip) {
    GuideTip.actionCards => l10n.guideTipActionCardsBody,
    GuideTip.makeActionCards => l10n.guideTipMakeActionCardsBody,
    GuideTip.caregiverRole => l10n.guideTipCaregiverRoleBody,
    GuideTip.taskAnalysis => l10n.guideTipTaskAnalysisBody,
    GuideTip.rewards => l10n.guideTipRewardsBody,
  };
}

/// 가이드 팁 카드 (그리기만): 왼쪽 3D 그림 > 굵은 제목, 회색 한 줄, 오른쪽 위 닫기 x. 카드 전체가 누름 영역
/// 글은 줄이지 않고 어절 단위로 줄을 바꿈 (큰 글자, 긴 번역에서도 잘리지 않게)
class GuideTipCard extends StatelessWidget {
  const GuideTipCard({
    super.key,
    required this.pictureAsset,
    required this.title,
    required this.body,
    required this.dismissLabel,
    required this.onTap,
    required this.onDismiss,
  });

  final String pictureAsset;
  final String title;
  final String body;

  /// 닫기 x 낭독 글
  final String dismissLabel;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  static const _minHeight = 72.0;

  /// 카드 판 안쪽 위아래 여백 더함 (판 기본 8 + 4 = 12)
  static const _extraVerticalPadding = 4.0;

  /// 3D 그림 44 (바탕 없음, 그림 자체가 입체)
  static const _pictureSize = 44.0;

  /// 제목 > 설명 간격
  static const _titleToBody = 2.0;

  /// 닫기 x: 보이는 크기 10, 누름 영역 36 (카드 오른쪽 위 모서리). 글은 x 자리만큼 비켜 둠
  static const _closeIconSize = 10.0;
  static const _closeTapSize = 36.0;
  static const _closeTextGap = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Stack(
      children: [
        AppPressable(
          onTap: withTapHaptic(onTap),
          scaleDown: AppPressable.scaleCard,
          child: Semantics(
            button: true,
            link: true,
            child: ElumRowCardFrame(
              minHeight: _minHeight.h,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: _extraVerticalPadding.h),
                child: Row(
                  children: [
                    Image.asset(
                      pictureAsset,
                      width: _pictureSize.w,
                      height: _pictureSize.w,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                    SizedBox(width: context.space.sm.w),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          KeptText(
                            title,
                            style: typo.creditTitle.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: _titleToBody.h),
                          KeptText(body, style: typo.creditBody.copyWith(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                    SizedBox(width: _closeTextGap.w),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: AppPressable(
            onTap: withTapHaptic(onDismiss),
            scaleDown: AppPressable.scaleIcon,
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
