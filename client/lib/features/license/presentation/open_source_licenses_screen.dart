import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/settings_group.dart';
import '../../../core/widgets/settings_tile.dart';
import '../application/open_source_license_providers.dart';
import '../domain/open_source_license.dart';
import 'license_failure_code.dart';
import 'license_text_screen.dart';
import 'software_licenses_screen.dart';

/// 오픈소스 라이선스: 그림 > 글꼴 > 프로그램 (#1046)
/// 앱에 전문을 담아 네트워크 없이도 읽음. 그림·글꼴은 프로그램 목록 실패와 상관없이 보임
class OpenSourceLicensesScreen extends StatelessWidget {
  const OpenSourceLicensesScreen({super.key});

  // 설정 계열 머리: 뒤로가기 y=67, 줄 x=16 (약관 목록과 같음)
  static const _backTop = ElumScaffold.settingsBackTop;
  static const _horizontalPadding = 16.0;
  // 뒤로가기 하단(107) > 안내 글 (약관 목록 첫 묶음과 같음)
  static const _headToBody = 24.0;
  static const _groupGap = 24.0;
  static const _guideInset = 16.0;
  static const _guideLineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ElumScaffold(
      onBack: () => Navigator.of(context).pop(),
      title: l10n.licenseScreenTitle,
      backTop: _backTop,
      horizontalPadding: _horizontalPadding,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: _headToBody.h),
            // 묶음 제목과 같은 시작선
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _guideInset.w),
              child: Text(
                l10n.licenseScreenGuide,
                style: context.typo.body.copyWith(
                  color: context.colors.textSecondary,
                  height: _guideLineHeight,
                ),
              ),
            ),
            SizedBox(height: _groupGap.h),
            SettingsGroup(
              header: l10n.licenseGroupArtwork,
              children: const [
                _BundledLicenseTile(kind: BundledLicenseKind.mulberrySymbols),
                _BundledLicenseTile(kind: BundledLicenseKind.twemoji),
              ],
            ),
            SizedBox(height: _groupGap.h),
            SettingsGroup(
              header: l10n.licenseGroupFonts,
              children: const [
                _BundledLicenseTile(kind: BundledLicenseKind.pretendard),
                _BundledLicenseTile(kind: BundledLicenseKind.tmoneyRoundWind),
              ],
            ),
            SizedBox(height: _groupGap.h),
            SettingsGroup(
              header: l10n.licenseGroupSoftware,
              children: [
                SettingsTile(
                  label: l10n.licenseSoftwareListRow,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SoftwareLicensesScreen(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.space.lg),
          ],
        ),
      ),
    );
  }
}

/// 그림·글꼴 1줄 > 전문 화면 (읽기 실패는 전문 화면이 보여 줌)
class _BundledLicenseTile extends ConsumerWidget {
  const _BundledLicenseTile({required this.kind});

  final BundledLicenseKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = _toDisplayName(context);
    return SettingsTile(
      label: name,
      valueText: _licenseTypeLabel,
      showChevronWithValue: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _BundledLicenseTextScreen(kind: kind, name: name),
        ),
      ),
    );
  }

  String _toDisplayName(BuildContext context) => switch (kind) {
        BundledLicenseKind.mulberrySymbols => 'Mulberry Symbols',
        BundledLicenseKind.twemoji => 'Twemoji',
        BundledLicenseKind.pretendard => 'Pretendard',
        BundledLicenseKind.tmoneyRoundWind => context.l10n.licenseFontTmoneyName,
      };

  // 티머니는 자체 약관이라 종류 표시 없음
  String? get _licenseTypeLabel => switch (kind) {
        BundledLicenseKind.mulberrySymbols => 'CC BY-SA 4.0',
        BundledLicenseKind.twemoji => 'CC BY 4.0',
        BundledLicenseKind.pretendard => 'OFL 1.1',
        BundledLicenseKind.tmoneyRoundWind => null,
      };
}

/// 자산 전문 읽기 > 전문 화면 (실패: 다시 시도 + 에러 코드)
class _BundledLicenseTextScreen extends ConsumerWidget {
  const _BundledLicenseTextScreen({required this.kind, required this.name});

  final BundledLicenseKind kind;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenseText = ref.watch(bundledLicenseTextProvider(kind));
    return LicenseTextScreen(
      name: name,
      fullText: licenseText.value,
      hasLoadFailed: licenseText.hasError,
      onRetry: () => ref.invalidate(bundledLicenseTextProvider(kind)),
      errorCode: licenseLoadFailureCode,
    );
  }
}
