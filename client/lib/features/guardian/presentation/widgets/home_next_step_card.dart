import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/app_reveal.dart';
import '../../../../core/widgets/elum_info_card.dart';
import '../../../link/application/linked_device_check.dart';
import '../../application/home_next_step.dart';

/// 「다음에 할 일」 카드 한 장 (홈 맨 위, 안내 카드보다 먼저): 3D 그림 + 제목 + 한 줄 + 행동 1개
/// 단계가 바뀌면 새 카드가 떠오름. none 이면 자리 없음. 판매·광고 없음
class HomeNextStepCard extends ConsumerWidget {
  const HomeNextStepCard({super.key, required this.onCreateRoutine, required this.bottomGap});

  /// 첫 일과 만들기 (홈 만들기 버튼과 같은 크레딧 확인)
  final Future<void> Function() onCreateRoutine;

  /// 카드 아래 간격 (카드가 보일 때만)
  final double bottomGap;

  /// 기기 연결: 연결 화면에서 돌아오면 연결 상태를 다시 받아 다음 단계로
  Future<void> _linkDevice(BuildContext context, WidgetRef ref) async {
    await context.push(Routes.linkCode);
    ref.refreshLinkedDevice();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(homeNextStepProvider);
    final content = _contentOf(context, ref, step);
    if (content == null) return const SizedBox.shrink();
    return AppReveal(
      key: ValueKey(step),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomGap.h),
        // 홈에서 지금 할 한 가지라 그림을 위에 크게 (작은 팁 카드와 구분)
        child: ElumInfoCard(
          layout: ElumInfoCardLayout.top,
          illustrationAsset: content.illustrationAsset,
          title: content.title,
          body: content.body,
          actionLabel: content.actionLabel,
          onAction: content.onAction,
        ),
      ),
    );
  }

  /// 단계 > 그림 · 글 · 행동 (none 은 null)
  _NextStepContent? _contentOf(BuildContext context, WidgetRef ref, HomeNextStep step) {
    final l10n = context.l10n;
    return switch (step) {
      HomeNextStep.makeFirstRoutine => (
        illustrationAsset: AppAssets.celebrationFirstRoutine,
        title: l10n.homeNextStepMakeTitle,
        body: l10n.homeNextStepMakeBody,
        actionLabel: l10n.homeNextStepMakeAction,
        onAction: onCreateRoutine,
      ),
      HomeNextStep.sendFirstRoutine => (
        illustrationAsset: AppAssets.emptyStateNoRoutines,
        title: l10n.homeNextStepSendTitle,
        body: l10n.homeNextStepSendBody,
        actionLabel: l10n.homeNextStepSendAction,
        onAction: () => context.push(Routes.guardianDrafts),
      ),
      HomeNextStep.linkDevice => (
        illustrationAsset: AppAssets.featureIconLinkDevice,
        title: l10n.homeNextStepLinkTitle,
        body: l10n.linkDeviceBenefitLine,
        actionLabel: l10n.routineSentLinkDevice,
        onAction: () => _linkDevice(context, ref),
      ),
      HomeNextStep.waitFirstCompletion => (
        illustrationAsset: AppAssets.celebrationSentToDevice,
        title: l10n.homeNextStepWaitTitle,
        body: l10n.elumiFinishNotifyLine,
        actionLabel: l10n.routineSentPreviewElumi,
        onAction: () => context.go(Routes.child),
      ),
      HomeNextStep.none => null,
    };
  }
}

/// 카드 한 장 내용
typedef _NextStepContent = ({
  String illustrationAsset,
  String title,
  String body,
  String actionLabel,
  VoidCallback onAction,
});
