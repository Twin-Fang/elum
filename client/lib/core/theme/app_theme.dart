import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// ThemeData 조립.
///
/// 토큰은 ThemeExtension으로 등록하되, 표준 Material 슬롯에도 매핑한다.
/// 그래야 기본 Flutter 위젯이 별도 설정 없이 올바른 스타일로 나온다.
abstract final class AppTheme {
  /// 한국어 테마. 기존 호출부 전부가 이것을 쓴다.
  static ThemeData get light => lightFor(const Locale('ko'));

  /// [locale] 의 대체 글꼴을 입힌 테마. `ko` 는 [light] 와 같다.
  static ThemeData lightFor(Locale locale) {
    const colors = AppColors.light;
    const typo = AppTypography.standard;
    final fallback = AppTypography.fontFamilyFallbackFor(locale);

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      // 비어 있으면 null 을 넘긴다 — ko 테마가 지금과 완전히 같게 한다.
      // 위젯이 TextStyle(fontFamily:) 를 직접 넘겨도 이 값이 상속된다.
      fontFamilyFallback: fallback.isEmpty ? null : fallback,
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
