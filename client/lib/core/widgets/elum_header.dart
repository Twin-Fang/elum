import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'elum_scaffold.dart';

/// 화면 상단 제목 블록 — 온보딩 6개 화면이 동일한 리듬을 공유한다.
///
/// Figma 실측 (화면 최상단 기준, 전 프레임 공통):
/// - 뒤로가기 y=79, 40×40 → 하단 119 (`976:4549`)
/// - 제목 y=131 (28/w800, 2줄, h=68) → 하단 199
/// - 설명 y=211 (16/w400) → 제목 하단과의 간격 12
/// - 첫 콘텐츠 y=279 → 설명 하단(227)과의 간격 52
///
/// 위 여백은 [ElumScaffold]가 상단 SafeArea를 보정한 뒤 이어받는다.
/// 뒤로가기가 있으면 그 아래(119)부터, 없으면 화면 최상단부터 계산한다.
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

  /// 위에 뒤로가기 버튼이 있는지.
  ///
  /// **[ElumScaffold] 안에서는 넘기지 않아도 된다** — 뼈대가
  /// [ElumScaffoldTopScope]로 직접 알려준다. 이 값은 뼈대 밖에서 쓸 때만 쓰인다.
  /// (예전엔 화면마다 손으로 넘겼는데 비밀번호·연결암호가 빠뜨려 제목이
  /// 40씩 내려가 있었다 — #297)
  final bool hasBackButton;

  /// Figma 제목 y좌표 (화면 최상단 기준)
  static const _titleY = 131.0;

  /// 뒤로가기 하단 (y=79 + 40). 뼈대 밖에서 쓸 때의 폴백값이다.
  static const _backBoxBottom = 119.0;

  /// 제목 하단(199) → 설명(211)
  static const _titleToDescription = 12.0;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;

    // 뼈대가 위에서 얼마를 썼는지 직접 읽는다. 뼈대 밖이면 넘겨받은 값을 쓴다.
    final consumedTop =
        ElumScaffoldTopScope.maybeOf(context) ??
        (hasBackButton ? _backBoxBottom : 0.0);

    // 뒤로가기가 있으면 뼈대가 119까지 소비했다 → 남은 간격은 131-119=12.
    // 없으면 화면 최상단부터이므로 SafeArea를 뺀 만큼 띄운다.
    final topGap = consumedTop > 0
        ? (_titleY - consumedTop).h
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
