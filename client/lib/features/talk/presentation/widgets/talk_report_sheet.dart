import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/network/server_error_code.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../domain/talk_report_reason.dart';
import '../../domain/talk_screen_codes.dart';
import 'talk_choice_row.dart';
import 'talk_sheet_frame.dart';

/// 신고 시트: 사유 4개 중 하나 > 보내기. 신고가 접수되거나 이미 신고한 글이면 true
/// [onSubmit] 이 실제 신고 요청 (글·댓글 구분은 호출한 쪽이 한다)
Future<bool> showTalkReportSheet(
  BuildContext context, {
  required Future<void> Function(TalkReportReason reason) onSubmit,
}) async {
  final isReported = await showElumSheet<bool>(
    context: context,
    builder: (_) => _TalkReportSheet(onSubmit: onSubmit),
  );
  return isReported ?? false;
}

String _reasonLabelOf(AppLocalizations l10n, TalkReportReason reason) =>
    switch (reason) {
      TalkReportReason.personalInfo => l10n.talkReportReasonPersonalInfo,
      TalkReportReason.offensive => l10n.talkReportReasonOffensive,
      TalkReportReason.advertising => l10n.talkReportReasonAdvertising,
      TalkReportReason.other => l10n.talkReportReasonOther,
    };

class _TalkReportSheet extends StatefulWidget {
  const _TalkReportSheet({required this.onSubmit});

  final Future<void> Function(TalkReportReason reason) onSubmit;

  @override
  State<_TalkReportSheet> createState() => _TalkReportSheetState();
}

class _TalkReportSheetState extends State<_TalkReportSheet> {
  TalkReportReason? _selectedReason;
  bool _isSending = false;

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null || _isSending) return;
    setState(() => _isSending = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await widget.onSubmit(reason);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final failure = AppFailure.of(e);
      // 이미 신고한 글: 서버 문구만 알리고 닫는다
      if (failure.server?.code == ServerErrorCode.talkReportDuplicated) {
        showElumToastOn(messenger, failure.messageOr(l10n.talkReportDone));
        Navigator.of(context).pop(false);
        return;
      }
      setState(() => _isSending = false);
      await showFailure(
        context,
        e,
        title: l10n.talkReportFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.report,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;

    return TalkSheetFrame(
      title: l10n.talkReportTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final reason in TalkReportReason.values) ...[
            TalkChoiceRow(
              label: _reasonLabelOf(l10n, reason),
              isSelected: reason == _selectedReason,
              onTap: _isSending
                  ? null
                  : () => setState(() => _selectedReason = reason),
            ),
            SizedBox(height: space.xs.h),
          ],
          SizedBox(height: space.xs.h),
          ElumButton(
            label: l10n.talkReportSubmit,
            loading: _isSending,
            onPressed: _selectedReason == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}
