import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/theme_context_ext.dart';
import 'elum_bottom_sheet.dart';
import 'elum_button.dart';

/// 알림 권한 안내 시트: 알림 받기(true) / 나중에(false) / 바깥을 눌러 닫기(null)
/// 시스템 권한 창을 띄우기 전에 왜 필요한지 먼저 알림 (다른 기능 화면이 쓰므로 core 에 둠)
Future<bool?> showPushPermissionSheet(BuildContext context) =>
    showElumSheet<bool>(
      context: context,
      builder: (_) => const _PushPermissionSheet(),
    );

class _PushPermissionSheet extends StatelessWidget {
  const _PushPermissionSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // 여백은 시트 면이 아니라 내용에 준다 (면에 주면 손잡이까지 밀려 제목과 겹친다)
    return ElumSheetSurface(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          space.screenH.w,
          (ElumSheetSurface.defaultHandleTop + space.lg).h,
          space.screenH.w,
          bottomInset + space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.pushPermissionSheetTitle,
              style: typo.sheetTitle.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: space.xs),
            Text(
              context.l10n.pushPermissionSheetBody,
              style: typo.promptBody.copyWith(color: colors.promptMuted),
            ),
            SizedBox(height: space.md),
            ElumButton(
              label: context.l10n.pushPermissionAllow,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            SizedBox(height: space.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                context.l10n.pushPermissionLater,
                style: typo.promptBody.copyWith(color: colors.promptMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
