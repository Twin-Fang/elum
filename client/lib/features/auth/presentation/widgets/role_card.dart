import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/app_role.dart';

/// 역할 선택 카드 (이슈 #212 · 명세 §4-3).
///
/// 온보딩 **도움 목표 칩**과 같은 규격(r20 테두리 카드 · 아이콘 40 · 좌여백 14)을
/// 쓰되, 제목 아래 설명 한 줄이 붙어 높이만 커진다.
///
/// 선택 상태를 두지 않는다 — **탭하면 바로 넘어가므로** 선택된 카드를 보여줄
/// 시간이 없다. `다음` 버튼이 없는 화면이라 선택 색을 만들면 쓸 자리가 없다.
class RoleCard extends StatelessWidget {
  const RoleCard({super.key, required this.role, this.onTap});

  final AppRole role;
  final VoidCallback? onTap;

  /// 목표 칩(68)보다 설명 한 줄만큼 높다.
  static const height = 96.0;

  /// 목표 칩과 같은 값 — 한 흐름 안에서 카드 여백이 달라지면 눈에 띈다.
  static const _iconLeft = 14.0;
  static const _iconToText = 12.0;
  static const _iconSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: height.h,
      padding: EdgeInsets.symmetric(horizontal: _iconLeft.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        border: Border.all(color: colors.border, width: context.space.borderWidth),
      ),
      child: Row(
        children: [
          // TODO(#198 D1 🎨): 역할 선택 전용 그림 2종이 나오면 교체한다.
          //   지금은 목표 아이콘을 빌려 쓴다 — 도형을 코드로 그리지 않기 위함이다.
          SvgPicture.asset(
            switch (role) {
              AppRole.guardian => AppAssets.roleGuardianMock,
              AppRole.elumi => AppAssets.roleElumiMock,
            },
            width: _iconSize.w,
            height: _iconSize.w,
          ),
          SizedBox(width: _iconToText.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  role.label,
                  style: context.typo.body.copyWith(color: colors.chipLabel),
                ),
                SizedBox(height: context.space.xs.h / 2),
                Text(
                  role.description,
                  style: context.typo.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
