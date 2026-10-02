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
      // 저장·변경 뒤 잠깐 뜨는 알림 (#543). **시안이 없는 임시 값이다.**
      //
      // 기본값은 colorScheme 에서 뽑힌 갈색 직사각형이 바닥에 붙어 앱과 따로 놀았다.
      // 띄우는 곳(7곳)이 문구만 넘기므로 여기 한 곳만 고치면 모두 바뀐다.
      // 시안이 나오면 이 값만 바꾼다 — 화면마다 스타일을 덧쓰지 않는다.
      snackBarTheme: SnackBarThemeData(
        // 바닥에 붙이지 않고 띄운다. 하단 광고·홈 인디케이터와 붙어 보이지 않게.
        behavior: SnackBarBehavior.floating,
        // 배경은 본문색(#242634). 화면 배경(#F7F2EF) 위에서 가장 또렷하고, 새 색을 만들지 않는다.
        backgroundColor: colors.textPrimary,
        // body 는 줄 높이 1.0 이라 이름이 길어 두 줄이 되면 위아래 줄이 붙는다.
        contentTextStyle: typo.body.copyWith(color: colors.surface, height: 1.4),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      extensions: const [colors, typo, AppSpacing.standard],
    );
  }
}
