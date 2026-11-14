import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pop_in.dart';
import '../../../../core/widgets/elum_toast.dart';

/// 두 번째부터의 보내기 알림: 민트 체크가 톡 튀어나오는 토스트 (첫 보내기는 축하 화면)
/// 화면을 옮기기 전에 잡아 둔 [messenger] 로 띄움
void showRoutineSentToastOn(ScaffoldMessengerState? messenger, String message) =>
    showElumToastOn(messenger, message, picture: const RoutineSentCheck());

/// 토스트 앞 체크: 연한 민트 판 + 진한 민트 체크, 등장 때 한 번 튐
class RoutineSentCheck extends StatelessWidget {
  const RoutineSentCheck({super.key});

  /// 체크 크기 (판 38 안)
  static const _checkSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPopIn(
      child: ColoredBox(
        color: colors.infoHighlightMintFill,
        child: Center(
          child: SvgPicture.asset(
            AppAssets.iconCheck,
            width: _checkSize.w,
            height: _checkSize.w,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(colors.infoHighlightMintAccent, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
