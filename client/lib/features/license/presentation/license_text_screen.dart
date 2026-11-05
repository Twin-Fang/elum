import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_spinner.dart';

/// 라이선스 전문 1건: 번역 없이 원문 그대로, 문단 단위로 보이는 만큼만 그림 (Flutter 원문은 매우 김)
class LicenseTextScreen extends StatelessWidget {
  const LicenseTextScreen({
    super.key,
    required this.name,
    required this.fullText,
    this.hasLoadFailed = false,
    this.onRetry,
    this.errorCode,
  });

  final String name;

  /// 아직 못 읽었으면 null
  final String? fullText;
  final bool hasLoadFailed;
  final VoidCallback? onRetry;
  final String? errorCode;

  static const _backTop = ElumScaffold.settingsBackTop;
  static const _headToBody = 40.0;
  // 문단 사이: 약관 전문 화면의 빈 줄 하나와 같음
  static const _paragraphGap = 14.0;
  static const _paragraphLineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      title: name,
      backTop: _backTop,
      child: Padding(
        padding: EdgeInsets.only(top: _headToBody.h),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (hasLoadFailed) {
      return ElumErrorView(
        message: context.l10n.licenseLoadFailedMessage,
        errorCode: errorCode,
        onRetry: onRetry,
      );
    }
    final fullText = this.fullText;
    if (fullText == null) return const Center(child: ElumSpinner());

    final paragraphs = fullText.split(RegExp(r'\n\s*\n'));
    // 색을 꼭 줌: 기본 본문 스타일이 보조색(회색)
    final paragraphStyle = context.typo.body.copyWith(
      color: context.colors.textPrimary,
      height: _paragraphLineHeight,
    );
    return ListView.builder(
      itemCount: paragraphs.length,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: _paragraphGap.h),
        child: Text(paragraphs[index].trim(), style: paragraphStyle),
      ),
    );
  }
}
