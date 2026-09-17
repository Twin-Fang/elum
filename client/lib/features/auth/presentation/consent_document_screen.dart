import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../domain/consent_documents.dart';

/// 약관 전문 화면.
///
/// **웹으로 보내지 않는다.** 외부 링크로 넘기면 로그인 흐름이 끊기고,
/// 네트워크가 없으면 읽을 수조차 없다. 읽을 수 없는 상태에서 받은 동의는
/// 고지로서 성립하지 않으므로 본문을 앱에 담아 보여준다.
class ConsentDocumentScreen extends StatelessWidget {
  const ConsentDocumentScreen({super.key, required this.item});

  final ConsentItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: context.space.xs.h),
            Text(
              item.required ? '[필수] ${item.label}' : '[선택] ${item.label}',
              style: context.typo.title,
            ),
            SizedBox(height: context.space.xs.h),
            Text(
              '버전 $consentVersion',
              style: context.typo.caption.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: context.space.lg.h),
            Text(
              item.body.trim(),
              // 약관은 줄 간격이 촘촘하면 읽기 어렵다. 본문보다 넉넉히 준다.
              style: context.typo.body.copyWith(height: 1.7),
            ),
            SizedBox(height: context.space.xl.h),
          ],
        ),
      ),
    );
  }
}
