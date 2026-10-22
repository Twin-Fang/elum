import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../assets/app_assets.dart';
import '../l10n/l10n_context.dart';
import '../layout/layout_context_ext.dart';
import '../theme/theme_context_ext.dart';
import '../widgets/elum_bottom_sheet.dart';
import '../widgets/elum_dialog.dart';
import '../widgets/elum_sheet_action_row.dart';

/// 업데이트 권유 안내 열기: 폰 > 바닥 시트, 태블릿 > 가운데 카드. 업데이트하기를 누르면 true
/// 이룸이도 보는 안내라 경고색·경고 아이콘 없이 루미 그림과 버튼 둘만 둠
Future<bool> showUpdateSuggestionPrompt(BuildContext context) async {
  final isTablet = context.layoutMetrics.isScaleOverridden;
  final bool? shouldOpenStore;
  if (isTablet) {
    shouldOpenStore = await showElumDialogContent<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _UpdateSuggestionCard(),
    );
  } else {
    shouldOpenStore = await showElumSheet<bool>(
      context: context,
      builder: (_) => const _UpdateSuggestionSheet(),
    );
  }
  return shouldOpenStore == true;
}

/// 폰: 손잡이 + 루미 + 제목·설명 + 시트 버튼 둘 (`나중에` 100 + `업데이트하기`, 시안 1869:8838 결)
class _UpdateSuggestionSheet extends StatelessWidget {
  const _UpdateSuggestionSheet();

  /// 루미 그림 크기 (정사각형)
  static const lumiSize = 168.0;

  /// 손잡이 아래 ~ 루미 더듬이 위 간격
  static const handleToLumiGap = 16.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // 손잡이는 여백 안쪽 기준으로 그려짐 > 위 여백 0, 손잡이 자리(위치 + 높이 4)를 비우고 그림 시작
    return ElumSheetSurface(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 22.h + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height:
                (ElumSheetSurface.defaultHandleTop + 4 + handleToLumiGap).h,
          ),
          Image.asset(
            AppAssets.updateSuggestionLumi,
            width: lumiSize.w,
            height: lumiSize.w,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 12.h),
          const _UpdateSuggestionText(textAlign: TextAlign.center),
          SizedBox(height: 24.h),
          ElumSheetActionRow(
            cancelLabel: context.l10n.updateSuggestionLater,
            onCancel: () => Navigator.of(context).pop(false),
            confirmLabel: context.l10n.appStatusGoUpdate,
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

/// 태블릿: 팝업 카드 (322, r20) 안에 루미 + 제목 · 설명 + 팝업 버튼 둘 (시안 팝업 931:4878 결)
class _UpdateSuggestionCard extends StatelessWidget {
  const _UpdateSuggestionCard();

  static const lumiSize = 120.0;
  static const _lumiToText = 12.0;
  static const _textToButtons = 24.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ElumDialogSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppAssets.updateSuggestionLumi,
                width: lumiSize.w,
                height: lumiSize.w,
                fit: BoxFit.contain,
              ),
              SizedBox(height: _lumiToText.h),
              const _UpdateSuggestionText(textAlign: TextAlign.center),
              SizedBox(height: _textToButtons.h),
              ElumDialogButtonRow(
                children: [
                  ElumDialogButton(
                    label: context.l10n.updateSuggestionLater,
                    tone: ElumDialogTone.neutral,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  ElumDialogButton(
                    label: context.l10n.appStatusGoUpdate,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
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
          style: typo.sheetTitle.copyWith(color: colors.sheetTitleText),
        ),
        SizedBox(height: 8.h),
        Text(
          l10n.updateSuggestionBody,
          textAlign: textAlign,
          style: typo.sheetDescription.copyWith(color: colors.sheetTitleText),
        ),
      ],
    );
  }
}
