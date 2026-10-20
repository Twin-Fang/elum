import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../assets/app_assets.dart';
import '../l10n/l10n_context.dart';
import '../layout/layout_context_ext.dart';
import '../theme/theme_context_ext.dart';
import '../widgets/elum_bottom_sheet.dart';
import '../widgets/elum_button.dart';

/// 업데이트 권유 안내 열기: 폰 > 바닥 시트, 태블릿 > 가운데 카드. 업데이트하기를 누르면 true
/// 이룸이도 보는 안내라 경고색·경고 아이콘 없이 루미 그림과 버튼 둘만 둠
Future<bool> showUpdateSuggestionPrompt(BuildContext context) async {
  final isTablet = context.layoutMetrics.isScaleOverridden;
  final bool? shouldOpenStore;
  if (isTablet) {
    shouldOpenStore = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierColor: context.colors.dialogScrim,
      builder: (_) => const _UpdateSuggestionCard(),
    );
  } else {
    shouldOpenStore = await showElumSheet<bool>(
      context: context,
      barrierColor: context.colors.sheetScrim,
      builder: (_) => const _UpdateSuggestionSheet(),
    );
  }
  return shouldOpenStore == true;
}

/// 폰: 손잡이 + 루미 + 제목·설명 + 업데이트하기 / 나중에 (세로로 쌓음)
class _UpdateSuggestionSheet extends StatelessWidget {
  const _UpdateSuggestionSheet();

  /// 루미 그림 크기 (정사각형)
  static const lumiSize = 168.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ElumSheetSurface(
      padding: EdgeInsets.fromLTRB(20.w, 34.h, 20.w, 20.h + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.updateSuggestionLumi,
            width: lumiSize.w,
            height: lumiSize.w,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 12.h),
          const _UpdateSuggestionText(textAlign: TextAlign.center),
          SizedBox(height: 24.h),
          const _UpdateButton(),
          SizedBox(height: 10.h),
          const _LaterButton(),
        ],
      ),
    );
  }
}

/// 태블릿: 흰 카드 안에 루미(왼쪽) + 제목·설명·버튼 둘(오른쪽)
class _UpdateSuggestionCard extends StatelessWidget {
  const _UpdateSuggestionCard();

  /// 카드 폭 상한: 넓은 화면에서 카드가 늘어나지 않게
  static const maxCardWidth = 560.0;
  static const lumiSize = 180.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxCardWidth.w),
          child: Material(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(24.r),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 28.h, 28.w, 28.h),
              child: Row(
                children: [
                  Image.asset(
                    AppAssets.updateSuggestionLumi,
                    width: lumiSize.w,
                    height: lumiSize.w,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _UpdateSuggestionText(
                          textAlign: TextAlign.start,
                        ),
                        SizedBox(height: 24.h),
                        Row(
                          children: [
                            const Expanded(flex: 2, child: _LaterButton()),
                            SizedBox(width: 10.w),
                            const Expanded(flex: 3, child: _UpdateButton()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 제목 + 설명 (폰은 가운데, 태블릿은 왼쪽 정렬)
class _UpdateSuggestionText extends StatelessWidget {
  const _UpdateSuggestionText({required this.textAlign});

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final crossAxisAlignment = textAlign == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          l10n.updateSuggestionTitle,
          textAlign: textAlign,
          style: typo.cardTitle.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: 8.h),
        Text(
          l10n.updateSuggestionBody,
          textAlign: textAlign,
          style: typo.promptBody.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _UpdateButton extends StatelessWidget {
  const _UpdateButton();

  @override
  Widget build(BuildContext context) => ElumButton(
        label: context.l10n.appStatusGoUpdate,
        onPressed: () => Navigator.of(context).pop(true),
      );
}

/// 나중에: 회색 버튼 (높이는 업데이트하기와 같게 둬 이룸이도 누르기 쉽게)
class _LaterButton extends StatelessWidget {
  const _LaterButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ElumButton(
      label: context.l10n.updateSuggestionLater,
      backgroundColor: colors.buttonNeutral,
      labelColor: colors.buttonNeutralText,
      onPressed: () => Navigator.of(context).pop(false),
    );
  }
}
