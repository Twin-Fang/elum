import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';

/// 올리기 화면 하단 고정 버튼 (null 이면 꺼진다)
class TalkShareBottomButton extends StatelessWidget {
  const TalkShareBottomButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.buttonMarginH.w,
        space.xs.h,
        space.buttonMarginH.w,
        space.md.h,
      ),
      child: ElumButton(label: label, loading: isLoading, onPressed: onPressed),
    );
  }
}
