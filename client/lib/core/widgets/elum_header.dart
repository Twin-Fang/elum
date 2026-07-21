import 'package:flutter/material.dart';

import '../theme/theme_context_ext.dart';

/// 화면 상단 제목 블록 — 온보딩 5개 화면이 동일한 리듬을 공유한다.
///
/// Figma 기준: 제목(28/w800, 2줄) y=131, 설명(16/w400) y=211.
class ElumHeader extends StatelessWidget {
  const ElumHeader({
    super.key,
    required this.title,
    this.description,
  });

  /// 2줄로 줄바꿈된 제목. 줄바꿈 위치는 디자인이 정한 대로 전달한다.
  final String title;

  final String? description;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: space.xl),
        Text(title, style: context.typo.title.copyWith(color: context.colors.textPrimary)),
        if (description != null) ...[
          SizedBox(height: space.sm),
          Text(
            description!,
            style: context.typo.body.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ],
    );
  }
}
