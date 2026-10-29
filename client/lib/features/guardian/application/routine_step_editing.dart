import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/state/single_flight.dart';
import '../../../shared/models/action_card.dart';
import '../../credit/application/credit_summary_refresh.dart';
import '../data/routine_repository.dart';
import '../domain/added_card_image_state.dart';
import 'routine_flow_state.dart';
import 'routine_providers.dart';

/// 카드 추가 결과: 실패, 새 카드 id, 그림 상태
typedef CardAddOutcome = ({
  AppFailure? failure,
  String? addedStepId,
  AddedCardImageState imageState,
});

/// 일과 카드 편집: 추가, 수정, 삭제, 순서 변경, 저장(승인)
/// 뺀 카드·바뀐 순서는 저장 전까지 로컬에만 두었다가 [save]가 서버에 반영
mixin RoutineStepEditing on Notifier<RoutineFlowState> {
  /// 화면에서 뺐지만 서버에는 아직 남아 있는 카드.
  ///
  /// [save]가 이것을 서버에 반영한다. **화면이 아니라 여기에 둔다** — 카드확인
  /// 화면은 저장 도중에도 다시 만들어질 수 있고, 목록에서 이미 사라진 카드는
  /// 화면에서 되찾을 방법이 없다.
  ///
  /// 지우는 데 성공한 것은 그때그때 뺀다. 하나가 실패해 다시 눌렀을 때 이미
  /// 없는 카드를 또 지우러 가면 안 된다.
  final _removedStepIds = <String>{};

  /// 일과 하나의 최대 카드 수 — 서버 `RoutineService.STEP_MAX_COUNT` 와 같은 값이다.
  ///
  /// 서버는 **자기가 가진 카드**를 센다. 보호자가 화면에서 뺀 카드는 저장하기 전까지 서버에
  /// 남아 있어서, 화면은 9장인데 서버는 10장이라 추가가 거절될 수 있다.
  static const _maxSteps = 10;

  /// 화면에서 카드 순서를 바꿨지만 서버에는 아직 안 보낸 상태.
  ///
  /// 뺀 카드([_removedStepIds])와 같은 이유로 **저장하기가 보낸다.** 서버 순서 API 는
  /// 카드 전체를 요구하는데(개수가 다르면 400) 뺀 카드는 그때까지 서버에 남아 있어서,
  /// 옮길 때마다 보내면 늘 실패한다. 저장하기는 삭제를 먼저 해 개수를 맞춘 뒤 보낸다.
  ///
  /// 순서를 바꿨다 되돌려도 true 로 남을 수 있다 — 한 번 더 보내는 것뿐이라 해가 없다.
  var _orderDirty = false;

  /// 다른 일과를 열거나 흐름을 초기화할 때 이전 일과의 미반영 편집을 버린다.
  void clearPendingStepChanges() {
    _removedStepIds.clear();
    _orderDirty = false;
  }

  /// 카드확인에서 카드를 직접 추가한다 (시안 1197:6044).
  ///
  /// 서버에 **바로** 넣는다 — 새 카드의 id 는 서버가 준다. 성공하면 새 카드를 화면
  /// 목록 **맨 뒤**에 붙인다. 서버가 돌려준 전체 목록을 그대로 쓰지 않는다: 그 안에는
  /// 보호자가 이미 뺀(저장 전이라 서버에 남은) 카드가 있어 되살아난다.
  ///
  /// failure 가 null 이면 성공. 실패하면 이유가 담겨 오고 목록은 그대로다.
  /// 그림은 서버가 그림 방식대로 커밋 뒤 채움 > [CardAddOutcome.imageState] 로 화면이 기다릴지 정함 (#868)
  Future<CardAddOutcome> addStep({
    required String title,
    required String description,
  }) async {
    // 제목·설명은 보호자가 쓴 글이라 로그에 남기지 않는다 (docs 원칙 5번)
    AppLogger.notifierCall('RoutineFlowNotifier', 'addStep');

    final routine = state.routine;
    if (routine == null) {
      return _addFailed(const AppFailure(fault: NetworkFault.app));
    }

    final repo = ref.read(routineRepositoryProvider);

    // 서버 카드가 상한이면(화면에서 뺀 카드까지 세어) 뺀 카드를 먼저 지운다. 안 그러면 화면은
    // 9장인데 "카드는 10장까지 만들 수 있습니다" 로 거절돼 보호자가 이유를 알 수 없다.
    // **꽉 찼을 때만** 미리 지운다 — 그 밖에는 나가기 팝업의 "뺀 카드는 저장하기를 눌러야
    // 빠져요" 를 그대로 지킨다. 하나라도 실패하면 추가하지 않는다.
    if (_removedStepIds.isNotEmpty &&
        routine.steps.length + _removedStepIds.length >= _maxSteps) {
      final failure = await _deleteRemovedSteps(repo, routine.id);
      if (failure != null) return _addFailed(failure);
    }

    final result = await repo.addStep(
      routine,
      title: title,
      description: description,
    );
    final failure = result.failure;
    if (failure != null) return _addFailed(failure);

    // 응답에서 새로 생긴 카드만 뽑는다. 하나도 없으면 서버가 무엇을 했는지 알 수 없다 —
    // 없는 카드를 만들어 내지 않고 실패로 본다.
    final known = {for (final s in routine.steps) s.id, ..._removedStepIds};
    final added = [
      for (final s in result.routine.steps)
        if (!known.contains(s.id)) s,
    ];
    if (added.isEmpty) {
      return _addFailed(const AppFailure(fault: NetworkFault.app));
    }

    // 서버 응답에는 카드 제목이 없다(RoutineStep 에 title 컬럼이 없다) —
    // 보호자가 쓴 제목을 되살린다.
    final withTitle = [
      for (final s in added) s.title.isEmpty ? s.copyWith(title: title) : s,
    ];
    state = state.copyWith(
      routine: routine.copyWith(steps: [...routine.steps, ...withTitle]),
    );

    final imageState = AddedCardImageState.fromAddResponse(
      imageSkippedReason: result.imageSkippedReason,
      description: description,
    );
    // 그림 1장 크레딧 예약됨 > 잔액 표시 갱신
    if (imageState == AddedCardImageState.generating) {
      refreshCreditSummary(ref);
    }
    return (
      failure: null,
      addedStepId: withTitle.last.id,
      imageState: imageState,
    );
  }

  CardAddOutcome _addFailed(AppFailure failure) => (
    failure: failure,
    addedStepId: null,
    imageState: AddedCardImageState.notRequested,
  );

  /// 그림을 기다리는 카드의 현재 그림 경로 (아직이면 null)
  Future<String?> fetchStepImagePath(String stepId) async {
    final routineId = state.routine?.id;
    if (routineId == null || routineId.isEmpty) return null;
    return ref
        .read(routineRepositoryProvider)
        .fetchStepImagePath(routineId, stepId);
  }

  /// 카드 그림을 사진으로 바꾼 뒤 새 `imagePath` 를 반영한다.
  ///
  /// 서버 응답 전체를 쓰지 않고 **`imagePath` 만** 바꾼다 — 응답에는 카드 제목이 없어
  /// 통째로 덮으면 로컬 제목이 지워진다([updateStep] 과 같은 사정). 그 사이 지워진 카드면
  /// 아무것도 하지 않는다. 목록 캐시도 버려, 홈·이룸이 쪽이 새 열쇠를 받게 한다.
  void applyStepImage(String stepId, String imagePath) {
    final routine = state.routine;
    if (routine == null || !routine.steps.any((s) => s.id == stepId)) return;

    state = state.copyWith(
      routine: routine.copyWith(
        steps: [
          for (final s in routine.steps)
            if (s.id == stepId) s.copyWith(imagePath: imagePath) else s,
        ],
      ),
    );
    ref.refreshRoutines();
  }

  /// 순서 변경 모드에 들어가는 순간의 순서. `✕` 로 나올 때 되돌린다.
  ({List<ActionCard> steps, bool dirty}) snapshotOrder() => (
    steps: List.of(state.routine?.steps ?? const <ActionCard>[]),
    dirty: _orderDirty,
  );

  /// [snapshotOrder] 로 되돌린다.
  void restoreOrder(({List<ActionCard> steps, bool dirty}) snapshot) {
    final routine = state.routine;
    if (routine == null) return;
    _orderDirty = snapshot.dirty;
    state = state.copyWith(routine: routine.copyWith(steps: snapshot.steps));
  }

  /// 카드 한 장을 옮긴다 (시안 1197:5798 길게 눌러 순서 변경).
  ///
  /// [newIndex] 는 `ReorderableListView.onReorder` 가 주는 값 그대로다 — 아래로
  /// 옮길 때 **제거 전** 위치를 주므로 여기서 하나 뺀다. 범위를 벗어나면 무시한다.
  /// 서버는 부르지 않는다. [save] 가 보낸다.
  void moveStep(int oldIndex, int newIndex) {
    final routine = state.routine;
    if (routine == null) return;
    final steps = List.of(routine.steps);
    if (oldIndex < 0 || oldIndex >= steps.length) return;
    if (newIndex < 0 || newIndex > steps.length) return;

    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target == oldIndex) return;

    steps.insert(target, steps.removeAt(oldIndex));
    _orderDirty = true;
    state = state.copyWith(
      routine: routine.copyWith(
        steps: [
          // 번호는 자리다 — 카드와 함께 옮기지 않고 자리대로 다시 매긴다
          for (var i = 0; i < steps.length; i++)
            steps[i].copyWith(stepOrder: i + 1),
        ],
      ),
    );
  }

  /// 카드확인에서 카드를 뺀다 (Figma 364:8305 X 버튼).
  ///
  /// 로컬에서만 지우고 서버 반영은 저장(승인) 시점의 목록으로 정리된다.
  /// **마지막 한 장은 지울 수 없다** — 카드 0장인 일과는 의미가 없다.
  void removeStep(String stepId) {
    AppLogger.notifierCall('RoutineFlowNotifier', 'removeStep', {
      'stepId': stepId,
    });

    final routine = state.routine;
    if (routine == null || routine.steps.length <= 1) return;
    if (!routine.steps.any((s) => s.id == stepId)) return;

    // 저장하기가 이 목록을 보고 서버에서 뺀다. 화면에서만 지우고 끝내면
    // 나가기 팝업의 "저장하기를 눌러야 빠져요" 가 지켜지지 않는다.
    _removedStepIds.add(stepId);

    state = state.copyWith(
      routine: routine.copyWith(
        steps: routine.steps.where((s) => s.id != stepId).toList(),
      ),
    );
  }

  /// 카드 제목·설명 수정 (Figma 262:5124 `이 카드 수정하기`).
  ///
  /// 돌려주는 값이 null 이 아니면 서버 반영에 실패해 로컬에만 저장됐다 —
  /// 그 안에 서버가 알려준 이유가 들어 있고, 화면이 그대로 안내한다.
  ///
  /// 제목·설명을 함께 서버에 보낸다. 응답 제목이 비어 오는 카드는
  /// 로컬 제목을 되살려 합친다.
  Future<AppFailure?> updateStep({
    required String stepId,
    required String title,
    required String description,
  }) async {
    AppLogger.notifierCall('RoutineFlowNotifier', 'updateStep', {
      'stepId': stepId,
      'titleLength': title.length,
      'descriptionLength': description.length,
    });

    final routine = state.routine;
    if (routine == null) return null;

    final repo = ref.read(routineRepositoryProvider);
    final result = await repo.updateStep(
      routine,
      stepId,
      title: title,
      description: description,
    );

    // 응답 제목이 비면 로컬 제목을 복원하고 수정한 카드는 입력값으로 덮는다
    final localTitles = {for (final step in routine.steps) step.id: step.title};
    final merged = result.routine.copyWith(
      steps: [
        for (final step in result.routine.steps)
          step.copyWith(
            title: step.id == stepId
                ? title
                : (step.title.isNotEmpty
                      ? step.title
                      : localTitles[step.id] ?? ''),
          ),
      ],
    );

    state = state.copyWith(routine: merged);
    return result.failure;
  }

  /// 화면에서 뺀 카드를 서버에서 지운다. [save] 와 [addStep] 이 함께 쓴다.
  ///
  /// null 이면 전부 지웠다. 하나라도 실패하면 이유를 돌려주고 **멈춘다** — 성공한 것은
  /// 기억에서 지워 다시 부를 때 남은 것만 보낸다.
  Future<AppFailure?> _deleteRemovedSteps(
    RoutineRepository repo,
    String routineId,
  ) async {
    for (final stepId in _removedStepIds.toList()) {
      final failure = await repo.deleteStep(routineId, stepId);

      // 이미 없는 카드는 빠진 것으로 본다 — 다른 휴대폰에서 먼저 지웠을 때다.
      // 결과가 같으므로 실패로 다루면 보호자가 영영 저장할 수 없다.
      final gone = failure?.server?.code == ServerErrorCode.routineStepNotFound;
      if (failure == null || gone) {
        _removedStepIds.remove(stepId);
        continue;
      }
      return failure;
    }
    return null;
  }

  /// 카드확인의 `저장하기`.
  ///
  /// 하는 일이 **일과의 상태에 따라 다르다.**
  ///
  /// | 어디서 왔나 | 상태 | 하는 일 |
  /// |---|---|---|
  /// | 만들기 흐름 | `PENDING_REVIEW` | 뺀 카드를 지우고 **승인**한다 |
  /// | 홈에서 편집 | 그 밖(`CONFIRMED`·`COMPLETED`) | 뺀 카드만 지운다 |
  ///
  /// 서버는 임시저장만 승인할 수 있어, 이미 저장한 일과에 승인 API 를 부르면
  /// `ROUTINE_INVALID_STATUS` 로 거절한다.
  ///
  /// **지우기가 먼저다.** 승인하는 순간 이룸이 화면에 카드가 나가므로(docs 원칙
  /// 3번), 순서가 바뀌면 뺀 카드가 잠깐이라도 이룸이에게 보인다.
  ///
  /// null 이면 성공. 실패하면 이유가 담겨 오고 **화면은 그대로 둔다** — 홈으로
  /// 보내면 저장된 것처럼 보이는데 이룸이 휴대폰에는 이전 카드가 그대로다.
  ///
  /// 진행 중에 다시 불리면 새로 보내지 않고 진행 중인 결과를 함께 받는다 — 두 번째 승인은
  /// 서버가 이미 끝난 일로 거절해, 저장은 됐는데 실패 팝업이 뜬다.
  Future<AppFailure?> save() => _saving.run(_save);

  final _saving = SingleFlight<AppFailure?>();

  Future<AppFailure?> _save() async {
    AppLogger.notifierCall('RoutineFlowNotifier', 'save', {
      'removed': _removedStepIds.length,
    });

    final routine = state.routine;
    if (routine == null) return null;

    final repo = ref.read(routineRepositoryProvider);

    // 뺀 카드를 서버에서 지운다. 하나라도 실패하면 승인하지 않는다 —
    // 뺀 카드가 남은 채로 이룸이에게 가면 보호자가 지운 것이 되살아난 셈이다.
    final deleteFailure = await _deleteRemovedSteps(repo, routine.id);
    if (deleteFailure != null) return deleteFailure;

    // 바꾼 순서를 보낸다. **삭제 다음이다** — 서버는 카드 전체를 요구해서 뺀 카드가
    // 남아 있으면 개수가 달라 거절한다. **승인 앞이다** — 승인하는 순간 이룸이 화면에
    // 카드가 나가므로 순서가 맞은 채로 나가야 한다.
    if (_orderDirty) {
      final failure = await repo.reorderSteps(routine.id, [
        for (final s in state.routine?.steps ?? routine.steps) s.id,
      ]);
      if (failure != null) return failure;
      _orderDirty = false;
    }

    // 이미 저장한 일과는 여기서 끝이다. 승인 API 는 임시저장만 받는다.
    if (routine.status != 'PENDING_REVIEW') {
      ref.refreshRoutines();
      return null;
    }

    AppLogger.notifierStateChange(
      'RoutineFlowNotifier',
      state.step.name,
      'done',
    );
    try {
      final confirmed = await repo.confirm(routine);
      state = state.copyWith(step: RoutineFlowStep.done, routine: confirmed);
      AppAnalytics.logRoutineConfirmed(cardCount: confirmed.steps.length);
    } catch (e) {
      AppLogger.error('RoutineFlowNotifier', e);
      return AppFailure.of(e);
    }
    ref.refreshRoutines();
    return null;
  }
}
