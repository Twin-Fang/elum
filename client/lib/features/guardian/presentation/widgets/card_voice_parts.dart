import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_spinner.dart';

/// 올리는 중 표시
class CardVoiceSpinner extends StatelessWidget {
  const CardVoiceSpinner({super.key});

  @override
  Widget build(BuildContext context) =>
      ElumSpinner(size: 20.w, strokeWidth: 2, color: context.colors.textPrimary);
}
