import 'package:flutter/material.dart';

import '../layout/app_layout.dart';
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
      // seed 는 시안 강조색(민트), 기본 부품 색은 남색. 주황 seed 면 스피너 · 커서가 주황 계열로 나온다
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.checkDone,
        primary: colors.textPrimary,
        surface: colors.surface,
      ),
      // 로딩 동그라미 (시안에 없음): 남색 한 가지
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.textPrimary,
      ),
      // 입력 커서는 남색, 고른 글자 · 손잡이는 민트 (고름 = 민트 결)
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.textPrimary,
        selectionColor: colors.goalSelectedFill,
        selectionHandleColor: colors.checkDone,
      ),
      textTheme: typo.toTextTheme(colors.textPrimary, colors.textSecondary),
      // 저장·변경 뒤 잠깐 뜨는 알림. **시안이 없는 임시 값이다.**
      //
      // 기본값은 colorScheme 에서 뽑힌 갈색 직사각형이 바닥에 붙어 앱과 따로 놀았다.
      // 띄우는 곳(7곳)이 문구만 넘기므로 여기 한 곳만 고치면 모두 바뀐다.
      // 시안이 나오면 이 값만 바꾼다 — 화면마다 스타일을 덧쓰지 않는다.
      snackBarTheme: SnackBarThemeData(
        // 바닥에 붙이지 않고 띄운다. 하단 광고·홈 인디케이터와 붙어 보이지 않게.
        behavior: SnackBarBehavior.floating,
        // 흰 판 + 1px 테두리 (시안 없음 > 팝업 결, design-language §4-6). 어두운 덩어리로 튀지 않게
        backgroundColor: colors.toastBackground,
        // body 는 줄 높이 1.0 이라 이름이 길어 두 줄이 되면 위아래 줄이 붙는다.
        contentTextStyle: typo.body.copyWith(color: colors.toastText, height: 1.4),
        // 문구 옆 누르는 글자(`보러 가기`)
        actionTextColor: colors.toastAction,
        // `보러 가기` 가 폭의 25% 를 넘으면 Flutter 가 아랫줄로 내려 토스트가 두 배로 커진다 > 한 줄에 둔다
        actionOverflowThreshold: 0.4,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.toastBorder),
        ),
        // 떠 있는 판의 옅은 그림자 (팝업 `4 4 6` 5% 에 가장 가까운 Material 높이)
        elevation: 2,
      ),
      extensions: const [colors, typo, AppSpacing.standard, AppLayout.standard],
    );
  }
}
