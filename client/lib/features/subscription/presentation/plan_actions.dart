import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/plan_status_providers.dart';
import '../application/store_purchase_coordinator.dart';
import '../domain/plan_catalog.dart';
import '../domain/plan_error_code.dart';

/// 결제: 보호자 암호 확인 > 결제창 (결과는 결제 단계로 화면에 옴). 암호를 안 넣고 돌아오면 아무것도 안 함
Future<void> confirmGuardianAndBuy(
  BuildContext context,
  WidgetRef ref,
  PlanOffer offer,
) async {
  final isConfirmed = await context.push<bool>(Routes.guardianPlanPin);
  if (isConfirmed != true || !context.mounted) return;
  await ref.read(storePurchaseCoordinatorProvider).buy(offer);
}

/// 이 기기의 스토어가 App Store 인가 (스토어별 확인 경로 · 버튼 문구, 아니면 Play 스토어)
bool get isAppStoreDevice => defaultTargetPlatform == TargetPlatform.iOS;

/// 구매 복원: 대기 팝업 > 복원 > 결과 팝업 (되찾음 · 없음 + 확인할 계정 · 실패 + 코드)
Future<void> restorePlanPurchases(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n; // await 뒤 context 를 읽지 않으려고 미리 잡음
  unawaited(
    showElumDialogContent<void>(
      context: context,
      builder: (_) => const PopScope(canPop: false, child: _RestoringDialog()),
    ),
  );
  final outcome = await ref.read(storePurchaseCoordinatorProvider).restore();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  switch (outcome.result) {
    case PlanRestoreResult.restored:
      await showElumDialog<void>(
        context: context,
        icon: ElumDialogIcon.success,
        title: l10n.planRestoreDone,
        actions: [ElumDialogAction(label: l10n.commonConfirm)],
      );
    case PlanRestoreResult.nothingToRestore:
      await showElumDialog<void>(
        context: context,
        title: l10n.planRestoreNothing,
        message: isAppStoreDevice ? l10n.planRestoreNothingHintApple : l10n.planRestoreNothingHintGoogle,
        actions: [ElumDialogAction(label: l10n.commonConfirm)],
      );
    case PlanRestoreResult.failed:
      await showFailure(
        context,
        outcome.failure,
        title: l10n.planRestoreFailedTitle,
        fallback: l10n.planFailedFallback,
        fallbackCode: PlanErrorCode.restore,
      );
  }
}

/// 스토어 구독 관리 화면 열기 (해지·결제 수단 변경은 스토어에서만 가능)
Future<void> openSubscriptionManagement(BuildContext context, WidgetRef ref) async {
  final productId = ref.read(memberSubscriptionProvider)?.productId;
  final url = AppConfig.subscriptionManagementUrl(
    defaultTargetPlatform,
    productId: productId,
  );
  final isOpened = url != null && await _openExternal(url, step: 'manage');
  if (isOpened || !context.mounted) return;
  await showFailure(
    context,
    null,
    fallback: context.l10n.planManageFailed,
    fallbackCode: PlanErrorCode.manage,
  );
}

/// 이용약관: 게시 주소가 있으면 브라우저, 없으면 앱 안 약관 화면
Future<void> openTermsOfUse(BuildContext context) async {
  final url = Uri.tryParse(AppConfig.termsOfUseUrl);
  if (url == null || !url.hasScheme) {
    await context.push<void>(Routes.guardianTerms);
    return;
  }
  await _openLegalLink(context, url);
}

/// 개인정보처리방침 게시 페이지
Future<void> openPrivacyPolicy(BuildContext context) async {
  final url = Uri.tryParse(AppConfig.privacyPolicyUrl);
  if (url == null) return;
  await _openLegalLink(context, url);
}

Future<void> _openLegalLink(BuildContext context, Uri url) async {
  if (await _openExternal(url, step: 'legal') || !context.mounted) return;
  await showFailure(
    context,
    null,
    fallback: context.l10n.planLinkFailed,
    fallbackCode: PlanErrorCode.legalLink,
  );
}

/// https 주소만 외부 앱(브라우저·스토어)으로 연다. 열었으면 true
Future<bool> _openExternal(Uri url, {required String step}) async {
  if (url.scheme != 'https') return false;
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (error, stack) {
    AppLogger.error('[plan link] open failed', error, stack, {'step': step, 'host': url.host});
    return false;
  }
}

/// 구매 복원 대기 팝업 (닫을 수 없음 — 끝나면 흐름이 직접 닫음)
class _RestoringDialog extends StatelessWidget {
  const _RestoringDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: ElumDialogSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElumSpinner(size: 32.w, strokeWidth: 3),
            SizedBox(height: 20.h),
            Text(
              context.l10n.planRestoring,
              textAlign: TextAlign.center,
              style: context.typo.dialogTitle.copyWith(
                color: context.colors.dialogTitleText,
              ),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}
