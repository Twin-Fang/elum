import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/app_role.dart';

/// 역할 선택 카드 (Figma `732:5176`·`732:5258` · 이슈 #229).
///
/// ## 아이콘을 두지 않는다
///
/// 전에는 왼쪽에 그림을 뒀다. 디자인에 없다 — **제목의 색이 그 역할을 한다.**
/// `보호자`는 민트, `이룸이`는 주황이라 글을 빨리 읽지 못해도 구분된다.
///
/// ## 선택 상태가 생겼다
///
/// 전에는 탭하면 바로 넘어가 선택을 보여줄 시간이 없었다. 이제 `다음`으로 확정하므로
/// **고른 카드가 남아 있어야** 무엇을 골랐는지 알 수 있다.
class RoleCard extends StatelessWidget {
  const RoleCard({super.key, required this.role, required this.selected});

  final AppRole role;
  final bool selected;

  /// Figma 실측 — 344×96 r20
  static const height = 96.0;

  /// 카드 안쪽 여백 (제목·설명 모두 x=24)
  static const _padding = 24.0;

  /// 제목 하단(44) → 설명(56)
  static const _titleToDescription = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: height.h,
      padding: EdgeInsets.symmetric(horizontal: _padding.w),
      decoration: BoxDecoration(
        color: selected ? colors.consentSelectedFill : colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
        border: Border.all(
          color: selected ? colors.consentSelectedBorder : colors.border,
          width: selected ? space.selectedBorderWidth : space.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 제목은 두 조각이다 — 앞부분만 색이 다르다.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: role.roleWord,
                  style: TextStyle(
                    color: switch (role) {
                      AppRole.guardian => colors.checkDone,
                      AppRole.elumi => colors.roleElumi,
                    },
                  ),
                ),
                TextSpan(text: role.labelSuffix),
              ],
            ),
            style: context.typo.subtitle.copyWith(color: colors.chipLabel),
          ),
          SizedBox(height: _titleToDescription.h),
          Text(
            role.description,
            style: context.typo.body.copyWith(color: colors.chipLabel),
          ),
        ],
      ),
    );
  }
}
