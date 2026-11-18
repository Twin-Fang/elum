part of 'card_review_screen.dart';

/// 카드 확인 화면 조각: 저장 흐름 · 저장 버튼 · 머리 묶음 · 카드 넘기기 (한 열 · 두 칸 배치가 함께 씀, #1457)
extension _CardReviewScreenParts on _CardReviewScreenState {
  /// 저장 버튼 (순서 변경 중엔 완료). 고른 반복은 둘째 줄 (카드 높이 그대로, #1457)
  Widget _buildSaveButton() => KeyedSubtree(
    key: _coachKeys.save,
    child: ElumButton(
      label: _reorderMode
          ? context.l10n.cardReviewReorderDone
          : context.l10n.cardReviewSave,
      onPressed: _reorderMode ? _finishReorder : _save,
      loading: busy,
      caption: switch (pickedScheduleSummary) {
        final scheduleSummary? when !_reorderMode && shouldShowScheduleTool =>
          context.l10n.cardReviewSaveWithSchedule(scheduleSummary),
        _ => null,
      },
    ),
  );

  /// 제목 · 안내 + (AI 메모리 규칙이 적용됐으면) 작은 알약
  Widget _buildHeadingBlock(Routine? routine) {
    final appliedMemoryRuleCount = routine?.appliedMemoryRuleCount ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CardReviewHeading(
          routine: routine,
          isReorderMode: _reorderMode,
          onTitleEditTap: renameRoutineInFlow,
        ),
        if (!_reorderMode && appliedMemoryRuleCount > 0) ...[
          SizedBox(height: 8.h),
          MemoryAppliedPill(count: appliedMemoryRuleCount),
        ],
      ],
    );
  }

  /// 카드 넘기기 (순서 변경 중엔 순서 목록). 두 칸은 칸 높이에 맞춘 폰 카드 비율로 가운데
  Widget _buildCardsView({
    required List<ActionCard> cards,
    required Routine? routine,
    required String routineId,
    required bool isWideLayout,
  }) {
    final notifier = ref.read(routineFlowProvider.notifier);
    if (_reorderMode) {
      return CardReviewReorderList(
        cards: cards,
        routineId: routineId,
        language: routine?.language ?? 'ko',
        cardWidth: CardReviewScreen._cardWidth,
        cardGap: CardReviewScreen._cardGap,
        onReorder: notifier.moveStep,
        initialIndex: _indexAtEnter,
        onFocusChanged: (index) => _reorderFocus = index,
      );
    }
    return PageView.builder(
      controller: _controller,
      itemCount: cards.length,
      // 카드를 넘기면 수정 버튼의 대상도 바뀐다
      onPageChanged: _onCardPageChanged,
      itemBuilder: (context, index) {
        // 카드가 도착하면 한 장씩 톡 튀어나옴 (처음 그려질 때 한 번)
        final card = AppPopIn(
          key: ValueKey('pop-${cards[index].id}'),
          delay: AppMotion.staggerDelayOf(index),
          child: ActionCardView(
            key: ValueKey(cards[index].id),
            card: cards[index],
            index: index,
            routineId: routineId,
            language: routine?.language ?? 'ko',
            onSpeak: () => _speak(cards[index]),
            isSpeaking: _speakingId == cards[index].id,
            isImageGenerating: isAddedCardImageGenerating(cards[index].id),
            // 마지막 한 장은 지울 수 없다 — 버튼 자체를 숨긴다
            onDelete: cards.length > 1
                ? () => _confirmRemove(cards[index])
                : null,
          ),
        );
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (CardReviewScreen._cardGap / 2).w,
          ),
          child: isWideLayout ? CardReviewWideCardSlot(child: card) : card,
        );
      },
    );
  }

  /// 저장(보내기) > (예약 도구로 고른 반복이 있으면) 반복 저장 > 첫 보내기 축하 또는 홈
  Future<void> _saveNow() async {
    final repeatSchedule = pickedRepeatSchedule;
    // 보내기인가 (임시저장 승인) · 첫 보내기인가: 저장 전에 판정 (저장 뒤에는 목록에 이 일과가 섞임)
    final firstSendCelebration = ref.read(firstSendCelebrationProvider);
    final isSending =
        ref.read(routineFlowProvider).routine?.status == _CardReviewScreenState._draftStatus;
    final isFirstSend =
        isSending && firstSendCelebration.isFirstSendBeforeSending();
    // 저장해야 이룸이 화면에 나간다. 뺀 카드를 서버에서 지우고, 만들기 흐름에서
    // 온 일과만 승인한다 — 이미 저장한 일과에 승인을 부르면 서버가 거절한다.
    final failure = await ref.read(routineFlowProvider.notifier).save();

    if (!mounted) return;

    // **실패하면 홈으로 보내지 않는다.** 홈으로 가면 저장된 것처럼 보이는데,
    // 정작 이룸이 휴대폰에는 아무것도 뜨지 않는다. 그때 보호자가 의심할 곳은
    // 앱이 아니라 이룸이다.
    if (failure != null) {
      showFailure(
        context,
        failure,
        title: context.l10n.cardReviewSaveFailedTitle,
        fallback: context.l10n.cardReviewSaveFailedFallback,
        fallbackCode: 'E-CONFIRM',
      );
      return;
    }
    final savedRoutineId = ref.read(routineFlowProvider).routine?.id;
    if (isSending) unawaited(firstSendCelebration.markSent());
    // 반복은 일과가 원본으로 저장된 뒤에만 정할 수 있음 (실패해도 일과는 보낸 채 이어 감)
    if (repeatSchedule != null) {
      await saveRepeatScheduleAfterSend(savedRoutineId, repeatSchedule);
    }
    if (!mounted) return;
    // 첫 보내기: 축하 화면 (알림 권한 안내 · AI 메모 확인은 축하에서 홈으로 갈 때)
    if (isFirstSend) {
      context.go(
        Routes.guardianRoutineSent,
        extra: (routineId: savedRoutineId),
      );
      return;
    }
    // 홈으로 가면 이 화면이 사라지므로 맨 위 네비게이터 컨텍스트와 안내 객체를 먼저 잡는다
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final pushPermissionPrompt = ref.read(pushPermissionPromptProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final sentMessage = context.l10n.routineSentTitle;
    context.go(Routes.guardian);
    // 두 번째 보내기부터는 체크가 튀는 가벼운 알림 (이미 보낸 일과 고치기는 알림 없음)
    if (isSending) showRoutineSentToastOn(messenger, sentMessage);
    // 첫 일과를 보낸 보호자에게 알림 권한 안내 (한 번만, 기다리지 않음)
    // 맨 위 네비게이터는 이 화면보다 오래 살고, maybeAsk 가 mounted 를 다시 확인함
    // ignore: use_build_context_synchronously
    unawaited(pushPermissionPrompt.maybeAsk(rootContext));
    // 고쳐서 보냈으면 AI 메모리가 찾은 수정을 물어봄 (Pro + 켜짐일 때만, 실패해도 조용히)
    // ignore: use_build_context_synchronously
    if (savedRoutineId != null) unawaited(showMemoryObservationsAfterSend(rootContext, savedRoutineId));
  }
}
