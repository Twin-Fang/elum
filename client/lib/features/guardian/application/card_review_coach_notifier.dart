import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';

/// 카드 검토 코치마크가 가리키는 순서
enum CardReviewCoachStep {
  /// `이 카드 수정` > 글·그림 고치기
  editCard,

  /// `카드 순서 변경` > 길게 눌러 끌기 (카드 1장이면 뺌)
  reorderCards,

  /// `카드 저장하기`
  save,
}

/// 코치마크 진행 상태. [steps]가 비어 있으면 꺼진 상태다.
class CardReviewCoachState {
  const CardReviewCoachState({this.steps = const [], this.index = 0});

  final List<CardReviewCoachStep> steps;
  final int index;

  bool get isActive => steps.isNotEmpty;

  CardReviewCoachStep? get current => isActive ? steps[index] : null;
}

final cardReviewCoachProvider =
    NotifierProvider<CardReviewCoachNotifier, CardReviewCoachState>(
      CardReviewCoachNotifier.new,
    );

/// 카드 검토 코치마크의 시작 조건과 진행. 규칙은 일과관리 코치마크와 같다.
///
/// **한 번 본 것은 기기에 남긴다.** 끝까지 봐도, 건너뛰어도, 닫아도 같다.
class CardReviewCoachNotifier extends Notifier<CardReviewCoachState> {
  /// 이번 실행에서 이미 띄웠는가. 저장에 실패해도 같은 실행에서 두 번 뜨지 않는다.
  bool _hasShownThisRun = false;

  @override
  CardReviewCoachState build() {
    // invalidate 는 Notifier 를 새로 만들지 않고 build 만 다시 부른다 — 필드도 함께 되돌린다
    _hasShownThisRun = false;
    return const CardReviewCoachState();
  }

  /// 카드 수 > 보여 줄 단계 (1장이면 순서를 바꿀 수 없어 순서 변경을 뺀다)
  static List<CardReviewCoachStep> stepsFor(int cardCount) => [
    CardReviewCoachStep.editCard,
    if (cardCount > 1) CardReviewCoachStep.reorderCards,
    CardReviewCoachStep.save,
  ];

  /// 안 봤으면 켠다 (켰으면 true). 읽지 못하면 **봤다고 친다** — 매번 뜨는 안내를 막는다
  bool maybeStart({required int cardCount}) {
    if (state.isActive || _hasShownThisRun) return false;
    final bool isSeen;
    try {
      isSeen = ref.read(localStorageProvider).isCardReviewCoachSeen;
    } catch (e) {
      AppLogger.error('CardReviewCoach.read', e);
      return false;
    }
    if (isSeen) return false;
    _hasShownThisRun = true;
    _turnOn(stepsFor(cardCount));
    return true;
  }

  /// 다시 보기 (`?` 버튼): 봤어도 켠다. 봤음 기록은 바꾸지 않는다
  void replay({required int cardCount}) {
    if (state.isActive) return;
    _turnOn(stepsFor(cardCount));
  }

  void _turnOn(List<CardReviewCoachStep> steps) {
    state = CardReviewCoachState(steps: steps);
    AppLogger.notifierCall('CardReviewCoachNotifier', 'start', {
      'steps': steps.length,
    });
  }

  /// 다음 단계로. 마지막이면 끝낸다.
  void next() {
    if (!state.isActive) return;
    if (state.index + 1 >= state.steps.length) {
      finish();
      return;
    }
    state = CardReviewCoachState(steps: state.steps, index: state.index + 1);
  }

  /// 끝낸다 — 마지막까지 봤든 중간에 닫았든 "본 것"으로 남긴다.
  /// 못 남겨도 이번 실행에서는 [_hasShownThisRun] 이 다시 뜨는 것을 막는다.
  Future<void> finish() async {
    if (!state.isActive) return;
    state = const CardReviewCoachState();
    try {
      await ref.read(localStorageProvider).setCardReviewCoachSeen(true);
    } catch (e) {
      AppLogger.error('CardReviewCoach.write', e);
    }
  }
}
