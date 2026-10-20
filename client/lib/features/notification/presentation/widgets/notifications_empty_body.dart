import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 알림이 하나도 없을 때: 루미 그림 + 안내 문구 (로딩·실패와 다른 화면)
class NotificationsEmptyBody extends StatelessWidget {
  const NotificationsEmptyBody({super.key});

  static const _illustrationSize = 160.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppAssets.notificationsEmptyLumi,
          width: _illustrationSize.w,
          height: _illustrationSize.w,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        SizedBox(height: context.space.lg),
        Text(
          context.l10n.notificationEmpty,
          textAlign: TextAlign.center,
          style: context.typo.creditHistoryRowTitle.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
