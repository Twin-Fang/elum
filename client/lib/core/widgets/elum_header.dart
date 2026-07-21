import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 화면 상단 제목 블록 — 온보딩 6개 화면이 동일한 리듬을 공유한다.
///
/// Figma 실측 (화면 최상단 기준, 전 프레임 공통):
/// - 뒤로가기 y=75, 24×24 → 하단 99
/// - 제목 y=131 (28/w800, 2줄, h=68) → 하단 199
/// - 설명 y=211 (16/w400) → 제목 하단과의 간격 12
/// - 첫 콘텐츠 y=279 → 설명 하단(227)과의 간격 52
///
/// 위 여백은 [ElumScaffold]가 상단 SafeArea를 보정한 뒤 이어받는다.
/// 뒤로가기가 있으면 그 아래(99)부터, 없으면 화면 최상단부터 계산한다.
class ElumHeader extends StatelessWidget {
  const ElumHeader({
    super.key,
    required this.title,
    this.description,
    this.hasBackButton = false,
  });

  /// 2줄로 줄바꿈된 제목. 줄바꿈 위치는 디자인이 정한 대로 전달한다.
  final String title;

  final String? description;

  /// 위에 뒤로가기 버튼이 있는지. [ElumScaffold]가 이미 그 높이를 소비했으므로
  /// 제목까지 남은 간격이 달라진다.
  final bool hasBackButton;

  /// Figma 제목 y좌표 (화면 최상단 기준)
  static const _titleY = 131.0;

  /// 뒤로가기 하단 (y=75 + 24)
  static const _backIconBottom = 99.0;

  /// 제목 하단(199) → 설명(211)
  static const _titleToDescription = 12.0;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;

    // 뒤로가기가 있으면 Scaffold가 99까지 소비했다 → 남은 간격은 131-99=32.
    // 없으면 화면 최상단부터이므로 SafeArea를 뺀 만큼 띄운다.
    final topGap = hasBackButton
        ? (_titleY - _backIconBottom).h
        : (_titleY.h - safeTop).clamp(0.0, _titleY.h);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topGap),
        Text(
          title,
          style: context.typo.title.copyWith(color: context.colors.textPrimary),
        ),
        if (description != null) ...[
          SizedBox(height: _titleToDescription.h),
          Text(
            description!,
            style:
                context.typo.body.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ],
    );
  }
}
