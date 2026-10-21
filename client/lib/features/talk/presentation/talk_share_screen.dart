import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/action_card.dart';
import '../application/talk_rules_provider.dart';
import '../application/talk_share_controller.dart';
import '../application/talk_shareable_routines_provider.dart';
import '../domain/talk_preview.dart';
import '../domain/talk_screen_codes.dart';
import 'widgets/talk_photo_blur_picker.dart';
import 'widgets/talk_routine_picker.dart';
import 'widgets/talk_rules_sheet.dart';
import 'widgets/talk_share_chrome.dart';
import 'widgets/talk_share_details_form.dart';

/// 올리기 화면의 단계: 이용 규칙 확인 중 > 일과 고르기 > 미리보기 받기 > 사진 고르기 > 한마디·분류
enum _ShareStage {
  checkingRules,
  pickRoutine,
  loadingPreview,
  pickPhotos,
  writeDetails,
}

/// 이야기 올리기: 규칙 동의 > 일과 고르기(입구가 일과를 주면 건너뜀) > 사진 흐리게(사진 카드가 있을 때만) > 한마디·분류·미리보기 > 올리기
class TalkShareScreen extends ConsumerStatefulWidget {
  const TalkShareScreen({super.key, this.initialRoutineId});

  /// 홈·상세 입구에서 들어오면 그 일과 (일과 고르기를 건너뛴다)
  final String? initialRoutineId;

  @override
  ConsumerState<TalkShareScreen> createState() => _TalkShareScreenState();
}

class _TalkShareScreenState extends ConsumerState<TalkShareScreen> {
  final _noteController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isRulesAgreed = false;

  /// 사진 고르기를 마치고 다음 단계로 넘어갔는가
  bool _isPhotoStepDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 이용 규칙 동의 확인 > (안 하면 닫기) > 입구가 준 일과가 있으면 미리보기 받기
  Future<void> _begin() async {
    final isAgreed = await ensureTalkRulesAgreed(
      context,
      ref,
      fallbackCode: TalkScreenCodes.share,
    );
    if (!mounted) return;
    if (!isAgreed) {
      context.popOrHome();
      return;
    }
    setState(() => _isRulesAgreed = true);
    final routineId = widget.initialRoutineId;
    if (routineId != null) await _selectRoutine(routineId);
  }

  Future<void> _selectRoutine(String routineId) {
    setState(() => _isPhotoStepDone = false);
    _noteController.clear();
    return ref
        .read(talkShareControllerProvider.notifier)
        .selectRoutine(routineId, context.l10n);
  }

  _ShareStage _stageOf(TalkShareState state) {
    if (!_isRulesAgreed) return _ShareStage.checkingRules;
    if (state.routineId == null) return _ShareStage.pickRoutine;
    if (state.preview == null) return _ShareStage.loadingPreview;
    if (state.hasGuardianPhoto && !_isPhotoStepDone) {
      return _ShareStage.pickPhotos;
    }
    return _ShareStage.writeDetails;
  }

  /// 한 단계 뒤로: 한마디 > 사진 > 일과 고르기 > 닫기 (입구가 일과를 줬으면 일과 고르기는 없다)
  void _goBack() {
    final state = ref.read(talkShareControllerProvider);
    if (state.isSubmitting) return;
    final stage = _stageOf(state);
    if (stage == _ShareStage.writeDetails && state.hasGuardianPhoto) {
      setState(() => _isPhotoStepDone = false);
      return;
    }
    final isRoutineChosenHere =
        widget.initialRoutineId == null && state.routineId != null;
    if (isRoutineChosenHere) {
      ref.read(talkShareControllerProvider.notifier).clearRoutine();
      setState(() => _isPhotoStepDone = false);
      return;
    }
    context.popOrHome();
  }

  void _goToDetails() {
    setState(() => _isPhotoStepDone = true);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// 올리기: 서버가 동의 안 함으로 거절하면 규칙 시트를 다시 띄우고 한 번만 다시 시도
  Future<void> _submit({bool canRetryAfterRules = true}) async {
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    // 화면을 옮긴 뒤에도 토스트를 띄우려고 미리 잡아 둔다
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final postId = await ref
          .read(talkShareControllerProvider.notifier)
          .submit();
      if (!mounted) return;
      router.pushReplacement(Routes.guardianTalkPostOf(postId));
      showElumToastOn(messenger, l10n.talkShareDone);
    } catch (e) {
      // 입력은 그대로 두고 안내만 띄운다
      if (!mounted) return;
      final isRulesRejected =
          canRetryAfterRules &&
          ref.read(talkRulesAgreementProvider.notifier).forgetIfRejected(e);
      if (isRulesRejected) {
        final isAgreed = await ensureTalkRulesAgreed(
          context,
          ref,
          fallbackCode: TalkScreenCodes.share,
        );
        if (isAgreed && mounted) await _submit(canRetryAfterRules: false);
        return;
      }
      await showFailure(
        context,
        e,
        title: l10n.talkShareFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.share,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(talkShareControllerProvider);
    final stage = _stageOf(state);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Column(
            children: [
              TalkShareHeader(onBackPressed: _goBack),
              Expanded(child: _body(stage, state)),
              if (stage == _ShareStage.pickPhotos ||
                  stage == _ShareStage.writeDetails)
                TalkShareBottomButton(
                  label: stage == _ShareStage.pickPhotos
                      ? context.l10n.talkSharePhotoNext
                      : context.l10n.talkShareSubmit,
                  isLoading: state.isSubmitting,
                  onPressed: stage == _ShareStage.pickPhotos
                      ? (state.hasChosenAllPhotos ? _goToDetails : null)
                      : (state.canSubmit ? _submit : null),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(_ShareStage stage, TalkShareState state) {
    final routineId = state.routineId;
    final preview = state.preview;
    return switch (stage) {
      _ShareStage.checkingRules => const ElumStateBody.loading(),
      _ShareStage.pickRoutine => TalkRoutinePicker(onSelected: _selectRoutine),
      _ShareStage.loadingPreview => _previewBody(state),
      _ShareStage.pickPhotos || _ShareStage.writeDetails =>
        routineId == null || preview == null
            ? const ElumStateBody.loading()
            : _scrollBody(routineId, preview, state, stage),
    };
  }

  /// 미리보기 받는 중 / 실패(다시 하기 + 에러 코드)
  Widget _previewBody(TalkShareState state) {
    final failure = state.previewFailure;
    final routineId = state.routineId;
    if (failure == null || routineId == null) {
      return const ElumStateBody.loading();
    }
    return ElumStateBody(
      child: ElumErrorView.failure(
        failure,
        fallback: context.l10n.talkSharePreviewFailed,
        fallbackCode: TalkScreenCodes.share,
        onRetry: () => _selectRoutine(routineId),
      ),
    );
  }

  Widget _scrollBody(
    String routineId,
    TalkPreview preview,
    TalkShareState state,
    _ShareStage stage,
  ) {
    final space = context.space;
    final controller = ref.read(talkShareControllerProvider.notifier);
    final sourceRoutine = ref.watch(talkShareSourceRoutineProvider(routineId));
    final cardByStepId = <String, ActionCard>{
      for (final card in sourceRoutine?.steps ?? const <ActionCard>[])
        card.id: card,
    };

    return SingleChildScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: space.screenH.w,
        vertical: space.sm.h,
      ),
      child: stage == _ShareStage.pickPhotos
          ? TalkPhotoBlurPicker(
              routineId: routineId,
              photoSteps: [
                for (final step in preview.steps)
                  if (step.isGuardianPhoto) step,
              ],
              cardByStepId: cardByStepId,
              blurChoiceByStepId: state.blurChoiceByStepId,
              onChoose: controller.chooseBlur,
            )
          : TalkShareDetailsForm(
              routineId: routineId,
              preview: preview,
              cardByStepId: cardByStepId,
              blurChoiceByStepId: state.blurChoiceByStepId,
              noteController: _noteController,
              category: state.category,
              isEnabled: !state.isSubmitting,
              onNoteChanged: controller.setNote,
              onCategorySelected: controller.setCategory,
            ),
    );
  }
}
