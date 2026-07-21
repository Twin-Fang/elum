import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// ThemeData 조립.
///
/// 토큰은 ThemeExtension으로 등록하되, 표준 Material 슬롯에도 매핑한다.
/// 그래야 기본 Flutter 위젯이 별도 설정 없이 올바른 스타일로 나온다.
abstract final class AppTheme {
  static ThemeData get light {
    const colors = AppColors.light;
    const typo = AppTypography.standard;

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.brandOrange,
        surface: colors.surface,
      ),
      textTheme: typo.toTextTheme(colors.textPrimary, colors.textSecondary),
      extensions: const [colors, typo, AppSpacing.standard],
    );
  }
}
