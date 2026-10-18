import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/widgets/elum_spinner.dart';
import 'grey_tile_shell.dart';

/// 목록 조회 중. 빈 상태와 구분되는 자리 표시.
class RoutineLoadingTile extends StatelessWidget {
  const RoutineLoadingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return GreyTileShell(
      child: Center(
        child: ElumSpinner(size: 20.w, strokeWidth: 2.w),
      ),
    );
  }
}
