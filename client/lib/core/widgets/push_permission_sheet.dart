import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import 'elum_bottom_sheet.dart';
import 'elum_button.dart';
import 'elum_sheet_frame.dart';
import 'elum_text_link.dart';

/// 알림 권한 안내 시트: 알림 받기(true) / 나중에(false) / 바깥을 눌러 닫기(null)
/// 시스템 권한 창을 띄우기 전에 왜 필요한지 먼저 알림 (다른 기능 화면이 쓰므로 core 에 둠)
/// 문구를 안 넘기면 첫 일과 직후 안내 문구 (다시 권하기·이룸이 기기는 넘김)
Future<bool?> showPushPermissionSheet(
  BuildContext context, {
  String? title,
  String? description,
  String? allowLabel,
}) =>
    showElumSheet<bool>(
      context: context,
      builder: (_) => _PushPermissionSheet(
        title: title,
        description: description,
        allowLabel: allowLabel,
      ),
    );

class _PushPermissionSheet extends StatelessWidget {
  const _PushPermissionSheet({
    this.title,
    this.description,
    this.allowLabel,
  });

  final String? title;
  final String? description;
  final String? allowLabel;

  /// 주 버튼 > `나중에` 글자 버튼 (시안 204:991 · 1082:4709: 24)
  static const _buttonToLink = 24.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ElumSheetFrame(
      title: title ?? l10n.pushPermissionSheetTitle,
      description: description ?? l10n.pushPermissionSheetBody,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumButton(
            label: allowLabel ?? l10n.pushPermissionAllow,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          SizedBox(height: _buttonToLink.h),
          ElumTextLink(
            label: l10n.pushPermissionLater,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
