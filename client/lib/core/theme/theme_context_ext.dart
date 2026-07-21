import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 테마 토큰 접근을 짧게 유지하는 확장.
///
/// `Theme.of(context).extension<AppColors>()!` 대신 `context.colors`를 쓴다.
/// 토큰은 AppTheme에서 항상 등록되므로 null이 될 수 없다.
extension ThemeContextExt on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppTypography get typo => Theme.of(this).extension<AppTypography>()!;
  AppSpacing get space => Theme.of(this).extension<AppSpacing>()!;
}
