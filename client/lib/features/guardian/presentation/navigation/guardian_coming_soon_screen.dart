import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import 'guardian_tab.dart';
import 'guardian_tab_icon.dart';

/// 아직 내용이 없는 칸 (지금은 이야기 #786): 칸 제목 + 준비 중 안내
///
/// 칸 자리를 먼저 열어 두고, 기능이 들어오면 이 화면을 그 칸의 화면으로 바꾼다.
class GuardianComingSoonScreen extends StatelessWidget {
  const GuardianComingSoonScreen({super.key, required this.tab});

  final GuardianTab tab;

  /// 안내 아이콘 한 변
  static const _iconSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final (title, body) = switch (tab) {
      GuardianTab.talk => (
        context.l10n.guardianTalkComingSoonTitle,
        context.l10n.guardianTalkComingSoonBody,
      ),
      // 홈·내정보는 이미 화면이 있다 — 라우터가 이 화면을 쓰지 않는다
      GuardianTab.home ||
      GuardianTab.manage ||
      GuardianTab.me => (tab.labelOf(context), ''),
    };

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: space.lg.h),
              // 칸 제목
              Text(
                tab.labelOf(context),
                style: context.typo.greeting.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              // 준비 중 안내 (가운데)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GuardianTabIcon(
                        tab: tab,
                        size: _iconSize.w,
                        color: colors.navIconUnselected,
                      ),
                      SizedBox(height: space.md.h),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: context.typo.sectionTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        SizedBox(height: space.xs.h),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: context.typo.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
