import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../l10n/l10n_context.dart';

/// 코치마크 닫기 ✕ (시안 1291:10802 - 안전영역 아래 8, 왼쪽 18)
/// 시안은 마지막 단계에만 그렸지만, 첫 단계에서 보고 싶지 않은 사람을 위해 모든 단계에 둠. 터치 영역은 48
class CoachMarkCloseButton extends StatelessWidget {
  const CoachMarkCloseButton({super.key, required this.onClose});

  final VoidCallback onClose;

  static const _hitSize = 48.0;
  static const _iconSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Positioned(
      left: 18.w - (_hitSize - _iconSize) / 2,
      top: media.padding.top + 8.h - (_hitSize - _iconSize) / 2,
      child: Semantics(
        button: true,
        label: context.l10n.coachCloseHint,
        onTap: onClose,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onClose();
          },
          child: SizedBox(
            width: _hitSize,
            height: _hitSize,
            child: Center(
              child: ExcludeSemantics(
                child: SvgPicture.asset(
                  AppAssets.coachClose,
                  width: _iconSize,
                  height: _iconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
