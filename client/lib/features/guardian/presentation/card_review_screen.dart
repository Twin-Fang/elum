import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../shared/models/action_card.dart';
import '../../child/data/speech_service.dart';
import '../application/routine_notifier.dart';
import '../data/card_photo.dart';
import 'widgets/action_card_view.dart';
import 'widgets/card_edit_sheet.dart';
import 'widgets/card_review_parts.dart';
import 'widgets/card_review_reorder_list.dart';
import 'widgets/aurora_background.dart';
import 'widgets/routine_flow_scaffold.dart';
import '../../../core/router/routes.dart';

/// Figma `보호자_카드확인`(1173:5541 기본 · 1197:5798 순서 변경).
///
/// 하단은 도구 버튼 3개(순서 변경 · 수정 · 추가)이고 순서 변경은 같은 화면이 모드로 바뀐다.
///
/// AI가 만든 카드를 보호자가 확인하고 저장한다. **승인 전에는 아동에게
/// 노출되지 않는다** (docs 원칙 3번).
///
/// 카드가 가로로 넘어가고 뒤 카드가 살짝 보인다. 몇 장인지 한눈에 알 수 있게
/// `viewportFraction`으로 옆 카드를 걸쳐 보여준다.
class CardReviewScreen extends ConsumerStatefulWidget {
  const CardReviewScreen({super.key});

  /// Figma 262:5124의 배경은 단색 #F7F2EF뿐이다 — 글로우가 없다.
  /// 흐름 배경이 이 값을 보고 오로라를 가라앉힌다.
  static const aurora = AuroraTone.none;

  /// 카드 폭과 카드 사이 (시안 `262:5124` 카드 333 @ x=30 · 옆 카드 x=373).
  ///
  /// 한 장 폭을 카드+사이로 잘라야 가운데 카드가 x=30 에 서고 옆 카드가 20 보인다.
  static const _cardWidth = 333.0;
  static const _cardGap = 10.0;

  /// 옆 카드가 걸쳐 보이는 정도. 1.0이면 한 장만 꽉 찬다.
  static const _viewportFraction = (_cardWidth + _cardGap) / 393;

  @override
  ConsumerState<CardReviewScreen> createState() => _CardReviewScreenState();
}

class _CardReviewScreenState extends ConsumerState<CardReviewScreen> {
  late PageController _controller = _newController(0);

  /// 순서 변경 모드를 나오면 페이지 뷰가 새로 만들어진다. 이전 위치를 기억하면 카드
  /// 순서가 바뀐 뒤 엉뚱한 카드에 서 있으므로, 나오는 쪽이 서 있을 카드를 정해 준다.
  static PageController _newController(int page) => PageController(
    initialPage: page,
    viewportFraction: CardReviewScreen._viewportFraction,
    keepPage: false,
  );

  /// 순서 변경 모드 (시안 1197:5798). 같은 화면이 모드로 바뀐다.
  var _reorderMode = false;

  /// 모드에 들어오는 순간의 순서. `✕` 가 이 순서로 되돌린다.
  ({List<ActionCard> steps, bool dirty})? _orderSnapshot;

  /// 모드에 들어올 때 보던 카드 자리 (`✕` 로 나오면 그 순서 그대로이니 여기로 돌아간다)
  int _indexAtEnter = 0;

  /// 순서 변경 모드에서 정면에 서 있는 카드 자리. `완료`로 나오면 그 카드부터 이어 본다.
  int _reorderFocus = 0;

  /// 지금 읽고 있는 카드 id. null이면 아무것도 안 읽고 있다.
  String? _speakingId;

  /// 지금 보고 있는 카드 인덱스. `이 카드 수정하기`가 이 카드를 대상으로 한다.
  int _currentIndex = 0;

  /// dispose에서 `ref`를 읽으면 "unmounted" 오류가 난다.
  /// 미리 잡아두고 정리할 때 쓴다.
  SpeechService? _speech;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 뒤에 잡는다. initState에서 읽어도 되지만 일관되게 둔다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speech = ref.read(speechServiceProvider);
    });
  }

  @override
  void dispose() {
    // 화면을 벗어나도 소리가 남으면 다음 화면까지 따라온다
    _speech?.stop();
    _controller.dispose();
    super.dispose();
  }

  /// 카드 지우기 — **묻고 나서** 뺀다.
  ///
  /// `✕` 가 곧바로 지우면 잘못 눌러도 되돌릴 길이 없다. 카드 그림은 AI 가 만든
  /// 것이라 다시 받으려면 크레딧이 든다. 일과 삭제 팝업과 같은 모양을 쓴다.
  /// 바깥을 눌러 닫으면 null 이므로 취소로 다룬다.
  Future<void> _confirmRemove(ActionCard card) async {
    final confirmed = await showElumDialog<bool>(
      context: context,
      title: context.l10n.cardReviewDeleteConfirmTitle,
      icon: ElumDialogIcon.trash,
      actions: [
        ElumDialogAction(
          label: context.l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: context.l10n.cardReviewDeleteAction,
          value: true,
          tone: ElumDialogTone.danger,
        ),
      ],
    );
    // 팝업이 떠 있는 사이 화면이 닫혔으면 건드리지 않는다
    if (confirmed != true || !mounted) return;
    ref.read(routineFlowProvider.notifier).removeStep(card.id);
  }

  /// 카드를 읽어준다. 읽는 중에 다시 누르면 멈춘다.
  ///
  /// 아동이 여러 번 누를 때 소리가 겹치면 알아들을 수 없다.
  Future<void> _speak(ActionCard card) async {
    final speech = ref.read(speechServiceProvider);

    if (_speakingId == card.id) {
      await speech.stop();
      if (mounted) setState(() => _speakingId = null);
      return;
    }

    setState(() => _speakingId = card.id);

    // 제목만 읽으면 무엇을 해야 하는지가 빠지고, 설명만 읽으면 화면의
    // 큰 제목과 어긋난다. 둘을 이어 붙인다.
    final ok = await speech.speak(
      '${card.displayTitle}. ${card.description}',
      language: ref.read(routineFlowProvider).routine?.language ?? 'ko',
    );

    if (!mounted) return;
    setState(() => _speakingId = null);

    if (!ok) _showFailure();
  }

  /// 소리를 낼 수 없을 때. 식별자는 보호자가 제보할 때 필요하다.
  void _showFailure() {
    showFailure(
      context,
      null,
      title: context.l10n.cardReviewSoundFailedTitle,
      fallback: context.l10n.cardReviewSoundFailedFallback,
      fallbackCode: 'E-TTS',
    );
  }

  Future<void> _save() async {
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
    context.go(Routes.guardian);
  }

  /// 지금 보고 있는 카드의 제목·설명을 바텀시트로 수정한다.
  Future<void> _edit(ActionCard card) async {
    final edited = await CardEditSheet.show(
      context,
      // displayTitle이 아니라 실제 title을 넘긴다. title이 없는 카드는
      // displayTitle이 description을 대신 돌려주는데, 그 값이 제목칸에 채워지면
      // 사용자가 제목을 안 고쳤을 때 title=description으로 저장돼 제목·설명이
      // 똑같아진다. title이 비면 제목칸도 비워 사용자가 직접 채우게 한다.
      title: card.title,
      description: card.description,
      // 서버 id 가 있는 카드만 사진으로 바꿀 수 있다. 아니면 칩이 없다.
      photo: CardPhotoTarget.of(
        routineId: ref.read(routineFlowProvider).routine?.id ?? '',
        stepId: card.id,
      ),
    );
    // 저장 없이 닫았다 — 아무것도 바꾸지 않는다
    if (edited == null || !mounted) return;

    final failure = await ref
        .read(routineFlowProvider.notifier)
        .updateStep(
          stepId: card.id,
          title: edited.title,
          description: edited.description,
        );

    // 서버 반영 실패 — 로컬에는 반영됐지만 저장하기(승인) 전에 앱을 끄면
    // 사라진다. 에러 코드가 있어야 제보를 추적할 수 있다.
    if (failure != null && mounted) {
      showFailure(
        context,
        failure,
        title: context.l10n.cardReviewEditFailedTitle,
        fallback: context.l10n.cardReviewEditFailedFallback,
        fallbackCode: 'E-STEP',
      );
    }
  }

  /// 새 카드를 직접 추가한다 (시안 1197:6044).
  ///
  /// 서버에 **시트 안에서** 넣는다 — 실패하면 시트가 열린 채 쓴 글이 남는다.
  /// 그림은 만들지 않는다(시안에 고르는 자리가 없다). 성공하면 새 카드로 넘어간다.
  Future<void> _add() async {
    final notifier = ref.read(routineFlowProvider.notifier);
    final before = ref.read(routineFlowProvider).routine?.steps.length ?? 0;

    final added = await CardEditSheet.showAdd(
      context,
      onSubmit: (title, description) async {
        final failure = await notifier.addStep(
          title: title,
          description: description,
        );
        if (failure == null) return true;
        if (mounted) {
          showFailure(
            context,
            failure,
            title: context.l10n.cardReviewAddFailedTitle,
            fallback: context.l10n.cardReviewAddFailedFallback,
            fallbackCode: 'E-STEP-ADD',
          );
        }
        return false;
      },
    );
    if (added == null || !mounted) return;

    // 새 카드는 맨 뒤다. 다음 프레임에 페이지 수가 늘어난 뒤 그 카드로 간다.
    final last = before; // 추가 전 개수 = 새 카드의 인덱스
    setState(() => _currentIndex = last);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.animateToPage(
          last,
          duration: AppMotion.normal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 순서 변경 모드에 들어간다. 읽던 소리는 끊는다 — 카드가 움직이는데 이어 읽으면 어긋난다.
  void _enterReorder() {
    _speech?.stop();
    setState(() {
      _speakingId = null;
      _orderSnapshot = ref.read(routineFlowProvider.notifier).snapshotOrder();
      // 보던 카드에서 시작한다 — 아니면 늘 1번으로 돌아간다.
      _indexAtEnter = _currentIndex;
      _reorderFocus = _currentIndex;
      _reorderMode = true;
    });
  }

  /// `완료` — 바꾼 순서를 두고 나온다. 서버에는 저장하기가 보낸다.
  void _finishReorder() => _leaveReorder(_reorderFocus);

  /// `✕`·시스템 뒤로 — 들어오기 전 순서로 되돌리고 나온다.
  void _cancelReorder() {
    final snapshot = _orderSnapshot;
    if (snapshot != null) {
      ref.read(routineFlowProvider.notifier).restoreOrder(snapshot);
    }
    _leaveReorder(_indexAtEnter);
  }

  /// 모드를 나온다. 페이지 뷰는 새로 만들어지므로 [index] 카드에 세워 이어 본다.
  void _leaveReorder(int index) {
    final last = ref.read(routineFlowProvider).routine?.steps.length ?? 1;
    final page = index.clamp(0, last > 0 ? last - 1 : 0);
    final old = _controller;
    setState(() {
      _reorderMode = false;
      _orderSnapshot = null;
      _currentIndex = page;
      _controller = _newController(page);
    });
    // 이전 컨트롤러는 모드 동안 붙은 화면이 없다. 새 프레임이 그려진 뒤 치운다.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final routine = ref.watch(routineFlowProvider).routine;
    final cards = routine?.steps ?? const <ActionCard>[];
    final routineId = routine?.id ?? '';
    final notifier = ref.read(routineFlowProvider.notifier);

    // 만들어진 카드가 없으면 확인할 것이 없다. 홈으로 돌려보낸다.
    if (cards.isEmpty) {
      return RoutineFlowScaffold(
        aurora: CardReviewScreen.aurora,
        child: CardReviewEmpty(
          // 같은 입력으로 다시 쏘면 서버가 같은 빈 일과를 돌려줄 수 있고 AI 비용도
          // 든다 — 흐름을 비우고 입력 첫 단계로 돌아간다.
          onRetry: () {
            notifier.reset();
            context.pushReplacement(Routes.routineInput);
          },
        ),
      );
    }

    return RoutineFlowScaffold(
      // 순서 변경 중에는 나가도 잃을 것이 없다 — 뒤로는 모드만 닫는다(되돌림 포함).
      // 그 밖에는 카드를 만든 순간 서버에 임시저장으로 남는다 — 나가도 날아가지 않는다.
      // 홈에서 편집하러 온 이미 저장한 일과는 뺀 카드만 저장하기를 기다린다.
      leave: _reorderMode
          ? null
          : routine?.status == 'PENDING_REVIEW'
          ? RoutineLeave.draft
          : RoutineLeave.edit,
      // 뒤로도 흐름을 떠난다 — 홈과 같이 묻고, 나가면 흐름을 연 화면(홈·임시저장)으로
      // 간다. 카드를 만든 뒤 흐름 안으로 되돌아가면 앞 화면들이 `남지 않아요` 라고
      // 사실과 다르게 말하고, 거기서 바꾼 보상·답은 다시 만들지 않아 버려진다.
      backLeavesFlow: true,
      onBack: _reorderMode ? _cancelReorder : () => leaveRoutineFlow(context),
      topBar: _reorderMode
          ? CardReviewReorderTopBar(onClose: _cancelReorder)
          : null,
      showDraftAction: !_reorderMode,
      // 저장 버튼은 시안 y=730~796 — 프레임 바닥에서 56
      bottomFigmaInset: 56,
      bottomButton: ElumButton(
        label: _reorderMode
            ? context.l10n.cardReviewReorderDone
            : context.l10n.cardReviewSave,
        onPressed: _reorderMode ? _finishReorder : _save,
      ),
      aurora: CardReviewScreen.aurora,
      child: Column(
        children: [
          // 상단바(끝 111) → 머리 y=123 → 카드 y=161. 순서 모드는 머리가 없어도 같은 높이다.
          SizedBox(height: 12.h),
          SizedBox(
            height: 22.h,
            child: _reorderMode ? null : CardReviewHead(count: cards.length),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: _reorderMode
                ? CardReviewReorderList(
                    cards: cards,
                    routineId: routineId,
                    language: routine?.language ?? 'ko',
                    cardWidth: CardReviewScreen._cardWidth,
                    cardGap: CardReviewScreen._cardGap,
                    onReorder: notifier.moveStep,
                    initialIndex: _indexAtEnter,
                    onFocusChanged: (index) => _reorderFocus = index,
                  )
                : PageView.builder(
                    controller: _controller,
                    itemCount: cards.length,
                    // 카드를 넘기면 수정 버튼의 대상도 바뀐다
                    onPageChanged: (index) =>
                        setState(() => _currentIndex = index),
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: (CardReviewScreen._cardGap / 2).w,
                      ),
                      child: ActionCardView(
                        key: ValueKey(cards[index].id),
                        card: cards[index],
                        index: index,
                        routineId: routineId,
                        language: routine?.language ?? 'ko',
                        onSpeak: () => _speak(cards[index]),
                        isSpeaking: _speakingId == cards[index].id,
                        // 마지막 한 장은 지울 수 없다 — 버튼 자체를 숨긴다
                        onDelete: cards.length > 1
                            ? () => _confirmRemove(cards[index])
                            : null,
                      ),
                    ),
                  ),
          ),
          // 카드 끝 571 → 보상 줄 587
          SizedBox(height: 16.h),
          if (_reorderMode)
            const CardReviewReorderHint()
          else
            CardReviewRewardRow(
              reward: routine?.hasReward ?? false
                  ? routine!.rewardDisplay
                  : null,
              rewardLanguage: routine?.language ?? 'ko',
              onTap: () => context.push(Routes.routineReward, extra: true),
            ),
          // 보상 줄 끝 633 → 도구 버튼 654
          SizedBox(height: 21.h),
          CardReviewToolRow(
            reorderMode: _reorderMode,
            onReorder: _enterReorder,
            // 눌린 버튼을 다시 누르면 `완료` 처럼 나온다
            onFinishReorder: _finishReorder,
            // 카드 삭제로 인덱스가 목록 밖을 가리킬 수 있어 clamp로 방어한다
            onEdit: () =>
                _edit(cards[_currentIndex.clamp(0, cards.length - 1)]),
            onAdd: _add,
          ),
        ],
      ),
    );
  }
}
