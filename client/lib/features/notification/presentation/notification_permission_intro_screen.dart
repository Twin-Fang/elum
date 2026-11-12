import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_guide_panel.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_text_link.dart';
import '../../credit/application/credit_costs.dart';
import '../../member/application/plan_access.dart';
import '../application/device_notification_permission_controller.dart';
import '../application/push_permission_prompt.dart';

/// 알림 켜기 안내 화면: 그림 > 제목 > 이유 한 줄 > 받는 알림 3줄 > `알림 켜기` · `나중에` (#1275)
/// 온보딩 끝(go 로 들어옴 > 홈으로) · 업데이트 뒤 홈 위(push 로 들어옴 > 닫기). 어느 버튼이든 앱 사용은 막지 않음
class NotificationPermissionIntroScreen extends ConsumerStatefulWidget {
  const NotificationPermissionIntroScreen({super.key});

  @override
  ConsumerState<NotificationPermissionIntroScreen> createState() => _NotificationPermissionIntroScreenState();
}

class _NotificationPermissionIntroScreenState extends ConsumerState<NotificationPermissionIntroScreen> {
  /// 권한 창이 떠 있는 동안 두 번째 누름 무시
  bool _isTurningOn = false;

  @override
  void initState() {
    super.initState();
    // 띄운 순간 기록 (다시 안 띄움, 홈 다시 권하기 시트와 겹치지 않게)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(pushPermissionPromptProvider).markIntroShown();
    });
  }

  /// 켜기: 홈 알림 꺼짐 카드와 같은 흐름 (안 물었으면 시스템 권한 창, 거부했으면 기기 설정) > 다음 화면
  Future<void> _turnOn() async {
    if (_isTurningOn) return;
    setState(() => _isTurningOn = true);
    await ref.read(deviceNotificationPermissionControllerProvider.notifier).turnOn();
    if (mounted) _leave();
  }

  /// 다음 화면: 홈 위에 떴으면 닫기, 온보딩 끝이면 보호자 홈
  void _leave() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(Routes.guardian);
  }

  @override
  Widget build(BuildContext context) {
    // 권한 상태를 지켜 둠 (켜기 중 provider 가 사라지지 않게)
    ref.watch(deviceNotificationPermissionControllerProvider);
    final l10n = context.l10n;
    final space = context.space;
    return PopScope(
      // 시스템 뒤로가기 = 나중에 (온보딩 끝은 스택이 없어 앱이 닫히지 않게)
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: ElumScaffold(
        bottomButton: ElumButton(label: l10n.pushPermissionTurnOn, loading: _isTurningOn, onPressed: _turnOn),
        belowButton: ElumTextLink(label: l10n.pushPermissionLater, onTap: _isTurningOn ? null : _leave),
        // 남는 높이에서는 가운데, 큰 글자에서 길어지면 스크롤
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: space.xl.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - space.xl.h * 2).clamp(0, double.infinity),
              ),
              child: Center(child: _panel(context)),
            ),
          ),
        ),
      ),
    );
  }

  /// 셋째 줄: 주간 리포트 권한 있으면 리포트, 없으면 크레딧 다시 채워짐 (주·달 단위)
  String _thirdRowTitle(AppLocalizations l10n) {
    if (ref.watch(planAccessProvider).canViewWeeklyReport) return l10n.notificationIntroWeeklyReport;
    return ref.watch(creditPeriodUnitProvider).notificationIntroCreditRefilled(l10n);
  }

  /// 그림 > 제목 > 이유 > 받는 알림 3줄
  Widget _panel(BuildContext context) {
    final l10n = context.l10n;
    return ElumGuidePanel(
      placement: ElumGuidePlacement.sheet,
      illustration: const ElumGuideIllustration(asset: AppAssets.homeNoticeBell, size: ElumGuideIllustrationSize.sheet),
      title: l10n.notificationIntroTitle,
      description: l10n.notificationIntroBody,
      // 받는 알림 3개
      content: [
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: l10n.notificationIntroRoutineDone),
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: l10n.notificationIntroCaregiverRoutine),
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: _thirdRowTitle(l10n)),
      ],
    );
  }
}
