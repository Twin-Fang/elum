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
import '../../../core/widgets/elum_secondary_button.dart';
import '../application/onboarding_exit_route.dart';

/// 온보딩 이룸이 기기 연결 단계: 그림 > 제목 > 이유 한 줄 > 소개 3줄 > `지금 연결하기` · `나중에 할게요`
/// 지금 연결하기 > 연결 암호 화면(온보딩 모드, 끝나면 온보딩 이어 감). 나중에 > 알림 안내 또는 홈
class LinkDeviceStepScreen extends ConsumerStatefulWidget {
  const LinkDeviceStepScreen({super.key});

  @override
  ConsumerState<LinkDeviceStepScreen> createState() => _LinkDeviceStepScreenState();
}

class _LinkDeviceStepScreenState extends ConsumerState<LinkDeviceStepScreen> {
  /// 다음 자리를 고르는 중 (두 번 누름 무시)
  bool _isLeaving = false;

  void _linkNow() => context.push(Routes.linkCodeFromOnboarding);

  /// 나중에: 알림 켜기 안내 차례면 안내, 아니면 홈 (go 로 온보딩 스택을 끝냄)
  Future<void> _later() async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    final nextRoute = await ref.read(onboardingExitRouteProvider).resolveAfterLinkStep();
    if (!mounted) return;
    context.go(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    return PopScope(
      // 비밀암호 화면이 go 로 끝나 돌아갈 곳이 없음 > 시스템 뒤로가기 = 나중에
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _later();
      },
      child: ElumScaffold(
        bottomButton: ElumButton(label: l10n.onboardingLinkStepConnectNow, onPressed: _isLeaving ? null : _linkNow),
        belowButton: ElumSecondaryButton(label: l10n.linkCodeLater, onTap: _isLeaving ? null : _later),
        // 남는 높이 가운데, 큰 글자에서 길어지면 스크롤
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

  /// 그림 > 제목 > 이유 > 소개 3줄 (코드 넣기 · 여러 대 · 설정에서도)
  Widget _panel(BuildContext context) {
    final l10n = context.l10n;
    return ElumGuidePanel(
      placement: ElumGuidePlacement.sheet,
      illustration: const ElumGuideIllustration(
        asset: AppAssets.emptyStateNotLinked,
        size: ElumGuideIllustrationSize.sheet,
      ),
      title: l10n.onboardingLinkStepTitle,
      description: l10n.linkDeviceBenefitLine,
      content: [
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: l10n.onboardingLinkStepEnterCode),
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: l10n.onboardingLinkStepManyDevices),
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: l10n.onboardingLinkStepLaterInSettings),
      ],
    );
  }
}
