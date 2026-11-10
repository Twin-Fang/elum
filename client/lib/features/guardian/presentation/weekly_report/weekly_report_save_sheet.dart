import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';

/// 리포트 저장 모양 2개
enum WeeklyReportSaveFormat { pdf, image }

/// 리포트 저장 시트: PDF · 이미지 고르기 > 고른 모양을 돌려줌, 닫으면 null
Future<WeeklyReportSaveFormat?> showWeeklyReportSaveSheet(BuildContext context) {
  return showElumSheet<WeeklyReportSaveFormat>(
    context: context,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return ElumSheetFrame(
        title: l10n.weeklyReportSaveSheetTitle,
        child: SettingsGroup(
          children: [
            SettingsTile(
              label: l10n.weeklyReportSharePdf,
              onTap: () => Navigator.of(sheetContext).pop(WeeklyReportSaveFormat.pdf),
            ),
            SettingsTile(
              label: l10n.weeklyReportShareImage,
              onTap: () => Navigator.of(sheetContext).pop(WeeklyReportSaveFormat.image),
            ),
          ],
        ),
      );
    },
  );
}
