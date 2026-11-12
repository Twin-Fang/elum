import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/models/action_card.dart';
import '../../../credit/application/credit_top_up_entry.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../application/card_photo_controller.dart';
import '../../application/routine_notifier.dart';
import '../../domain/image_redraw_hint.dart';
import 'card_image_candidate_sheet.dart';
import 'card_regenerate_sheet.dart';

/// 그리기 실패 팝업의 에러 코드 (서버 코드가 없을 때)
const cardRedrawErrorCode = 'E-CARD-REGENERATE';

/// 새 그림 받기·바꾸기 실패 팝업의 에러 코드 (서버 코드가 없을 때)
const cardCandidateErrorCode = 'E-CARD-CANDIDATE';

/// 카드 그림 새로 그리기 흐름: 요청 시트 > 그리기(진행 표시) > 새 그림 받기 > 나란히 고르기 > 바꾸기 · 버리기
///
/// 어느 단계에서 실패해도 카드 그림은 그대로 + 에러 코드 팝업. 서버 Pro 거절이면 실패 팝업 대신 Pro 안내.
/// 고르기 전에 시트를 닫거나 앱을 나가면 후보는 서버에 남고 다음 그리기가 덮는다 (카드 그림은 그대로)
Future<void> runCardRedrawFlow({
  required BuildContext context,
  required WidgetRef ref,
  required String routineId,
  required ActionCard step,
  required ValueChanged<bool> onDrawingChanged,
}) async {
  final isFirstPicture = !step.isAiPicture;
  final request = await CardRegenerateSheet.show(context, ref, isFirstPicture: isFirstPicture);
  if (request == null || !context.mounted) return;
  await _drawAndPick(
    context: context,
    ref: ref,
    routineId: routineId,
    step: step,
    request: request,
    onDrawingChanged: onDrawingChanged,
  );
}

/// 같은 요청으로 그리기 > 새 그림 받기 > 고르기 > 바꾸기 (크레딧 부족이면 크레딧 더 받기 시트, 받으면 `이어서 그리기` 로 다시)
Future<void> _drawAndPick({
  required BuildContext context,
  required WidgetRef ref,
  required String routineId,
  required ActionCard step,
  required CardRedrawRequest request,
  required ValueChanged<bool> onDrawingChanged,
}) async {
  final isFirstPicture = !step.isAiPicture;
  // await 뒤 시트가 사라져도 끝까지 반영할 수 있게 미리 잡아 둠
  final notifier = ref.read(routineFlowProvider.notifier);
  final controller = ref.read(cardPhotoControllerProvider);
  final rootContext = Overlay.of(context, rootOverlay: true).context;
  final messenger = ScaffoldMessenger.maybeOf(context);
  BuildContext targetContext() => context.mounted ? context : rootContext;

  // 그리기 > 새 그림 받기 (진행 표시는 둘을 합쳐 한 번)
  onDrawingChanged(true);
  final drawResult = await controller.drawCandidate(routineId: routineId, stepId: step.id, request: request);
  final candidate = drawResult.candidate;
  final candidateImageBytes = candidate == null
      ? null
      : await controller.fetchCandidateImage(routineId: routineId, stepId: step.id);
  if (context.mounted) onDrawingChanged(false);

  if (candidate == null) {
    final failureContext = targetContext();
    if (!failureContext.mounted) return;
    if (context.mounted && await handleProOnlyRejection(context, ref, drawResult.failure)) return;
    if (context.mounted && isCreditInsufficientFailure(drawResult.failure)) {
      await openCreditTopUpAfterShortage(
        context,
        ref,
        retry: (
          label: context.l10n.creditTopUpRedrawContinue,
          run: () async {
            if (!context.mounted) return;
            await _drawAndPick(
              context: context,
              ref: ref,
              routineId: routineId,
              step: step,
              request: request,
              onDrawingChanged: onDrawingChanged,
            );
          },
        ),
      );
      return;
    }
    if (!failureContext.mounted) return;
    await showFailure(
      failureContext,
      drawResult.failure,
      title: isFirstPicture ? failureContext.l10n.cardFirstDrawFailedTitle : failureContext.l10n.cardRegenerateFailedTitle,
      fallback: failureContext.l10n.cardRedrawFailedFallback,
      fallbackCode: cardRedrawErrorCode,
    );
    return;
  }
  if (candidateImageBytes == null) {
    final failureContext = targetContext();
    if (!failureContext.mounted) return;
    await showFailure(
      failureContext,
      null,
      title: failureContext.l10n.cardCandidateLoadFailedTitle,
      // 그리기는 끝나 크레딧을 이미 씀 (그리기 실패와 문구가 다름)
      fallback: failureContext.l10n.cardCandidateFailedFallback,
      fallbackCode: cardCandidateErrorCode,
    );
    return;
  }

  // 고르기 (시트를 띄울 자리가 없으면 후보만 남김)
  final pickContext = targetContext();
  if (!pickContext.mounted) return;
  final isApplied = await CardImageCandidateSheet.show(
    pickContext,
    routineId: routineId,
    step: step,
    candidateImageBytes: candidateImageBytes,
  );
  if (!isApplied) {
    // 원래 그림 그대로: 후보만 버림 (크레딧은 그릴 때 이미 씀)
    await controller.discardCandidate(routineId: routineId, stepId: step.id);
    return;
  }

  final applyResult = await controller.applyCandidate(
    routineId: routineId,
    stepId: step.id,
    candidateImagePath: candidate.candidateImagePath,
  );
  final appliedCard = applyResult.card;
  if (appliedCard != null) {
    // 새 imagePath 가 오면 이미지 캐시 열쇠가 달라져 그림이 바뀐다
    notifier.applyStepImage(step.id, appliedCard.imagePath!, isAiPicture: true);
    if (rootContext.mounted) showElumToastOn(messenger, rootContext.l10n.cardCandidateAppliedToast);
    return;
  }
  final failureContext = targetContext();
  if (!failureContext.mounted) return;
  await showFailure(
    failureContext,
    applyResult.failure,
    title: failureContext.l10n.cardCandidateApplyFailedTitle,
    fallback: failureContext.l10n.cardCandidateFailedFallback,
    fallbackCode: cardCandidateErrorCode,
  );
}
