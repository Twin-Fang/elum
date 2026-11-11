import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/settings_tile.dart';
import '../application/open_source_license_providers.dart';
import '../domain/open_source_license.dart';
import 'license_failure_code.dart';
import 'license_text_screen.dart';

/// 프로그램 라이선스 목록: 패키지 이름 + 종류 > 전문 (수백 건이라 보이는 줄만 그림)
class SoftwareLicensesScreen extends ConsumerWidget {
  const SoftwareLicensesScreen({super.key});

  static const _backTop = ElumScaffold.settingsBackTop;
  static const _horizontalPadding = 16.0;
  static const _headToBody = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final softwareLicenses = ref.watch(softwareLicensesProvider);
    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      title: l10n.licenseGroupSoftware,
      backTop: _backTop,
      horizontalPadding: _horizontalPadding,
      child: Padding(
        padding: EdgeInsets.only(top: _headToBody.h),
        child: softwareLicenses.when(
          data: (licenses) => _LicenseList(licenses: licenses),
          loading: () => const Center(child: ElumSpinner()),
          error: (_, _) => ElumErrorView(
            message: l10n.licenseLoadFailedMessage,
            errorCode: licenseLoadFailureCode,
            onRetry: () => ref.invalidate(softwareLicensesProvider),
          ),
        ),
      ),
    );
  }
}

class _LicenseList extends StatelessWidget {
  const _LicenseList({required this.licenses});

  final List<OpenSourceLicense> licenses;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: licenses.length,
      itemBuilder: (context, index) {
        final license = licenses[index];
        return SettingsTile(
          label: license.name,
          valueText:
              license.licenseTypeLabel.isEmpty ? null : license.licenseTypeLabel,
          showChevronWithValue: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LicenseTextScreen(
                name: license.name,
                fullText: license.fullText,
              ),
            ),
          ),
        );
      },
    );
  }
}
