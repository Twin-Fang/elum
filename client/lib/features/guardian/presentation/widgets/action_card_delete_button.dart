import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 카드 삭제 버튼 (Figma 262:5124 이미지 우상단 — 흐린 원 + X, 393:4010).
class ActionCardDeleteButton extends StatelessWidget {
  const ActionCardDeleteButton({super.key, required this.onTap});

  final VoidCallback onTap;

  /// Figma 실측 30×30. 그대로 두면 보호자 최소 터치 타겟(44)에 못 미쳐
  /// 투명 여백으로 넓힌다.
  static const _visualSize = 30.0;
  static const _touchSize = 44.0;

  /// 원이 그림칸 모서리에서 떨어진 거리 (시안 `262:5124`).
  static const designInset = 6.0;

  /// 누름 영역이 원보다 한쪽에 더 넓은 만큼.
  static const touchPad = (_touchSize - _visualSize) / 2;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: context.l10n.cardDeleteLabel,
      // 정사각형 버튼 — 가로세로 모두 .w
      child: SizedBox(
        width: _touchSize.w,
        height: _touchSize.w,
        child: Center(
          child: SvgPicture.asset(
            AppAssets.iconCardDelete,
            width: _visualSize.w,
            height: _visualSize.w,
          ),
        ),
      ),
    );
  }
}
