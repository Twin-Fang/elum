import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../guardian/domain/routine_template.dart';
import '../data/talk_repository.dart';
import '../domain/talk_category_suggester.dart';
import '../domain/talk_preview.dart';
import 'talk_lists_invalidation.dart';

/// 올리기 흐름 상태: 고른 일과, 미리보기, 사진별 흐리게 선택, 한마디, 분류, 올리는 중
@immutable
class TalkShareState {
  const TalkShareState({
    this.routineId,
    this.preview,
    this.isPreviewLoading = false,
    this.previewFailure,
    this.blurChoiceByStepId = const {},
    this.note = '',
    this.category,
    this.isSubmitting = false,
  });

  final String? routineId;
  final TalkPreview? preview;
  final bool isPreviewLoading;

  /// 미리보기를 못 받았을 때의 실패 (다시 시도 안내용)
  final AppFailure? previewFailure;

  /// 보호자 사진 카드 id > 흐리게 여부 (true 흐리게, false 그대로, null 아직 안 고름)
  final Map<String, bool?> blurChoiceByStepId;
  final String note;

  /// null 이면 아직 고르지 않음
  final RoutineTemplateCategory? category;
  final bool isSubmitting;

  /// 흐리게 선택 단계가 필요한가 (보호자 사진 카드가 있을 때만)
  bool get hasGuardianPhoto => preview?.hasGuardianPhoto ?? false;

  /// 사진 카드를 모두 골랐는가 (사진이 없으면 true)
  bool get hasChosenAllPhotos =>
      blurChoiceByStepId.values.every((choice) => choice != null);

  /// 서버에 보낼 "흐리게" 고른 카드 id
  List<String> get blurredStepIds => [
    for (final entry in blurChoiceByStepId.entries)
      if (entry.value == true) entry.key,
  ];

  /// 올릴 수 있는가: 미리보기 있음 + 사진 선택 끝 + 분류 고름 + 올리는 중 아님
  bool get canSubmit =>
      preview != null &&
      hasChosenAllPhotos &&
      category != null &&
      !isSubmitting;

  TalkShareState copyWith({
    Map<String, bool?>? blurChoiceByStepId,
    String? note,
    RoutineTemplateCategory? category,
    bool? isSubmitting,
  }) => TalkShareState(
    routineId: routineId,
    preview: preview,
    isPreviewLoading: isPreviewLoading,
    previewFailure: previewFailure,
    blurChoiceByStepId: blurChoiceByStepId ?? this.blurChoiceByStepId,
    note: note ?? this.note,
    category: category ?? this.category,
    isSubmitting: isSubmitting ?? this.isSubmitting,
  );
}

final talkShareControllerProvider =
    NotifierProvider.autoDispose<TalkShareController, TalkShareState>(
      TalkShareController.new,
    );

/// 올리기 흐름: 일과 고르기 > 미리보기 받기 > 사진·한마디·분류 입력 > 올리기
class TalkShareController extends Notifier<TalkShareState> {
  TalkRepository get _repository => ref.read(talkRepositoryProvider);

  @override
  TalkShareState build() => const TalkShareState();

  /// 일과를 고르고 미리보기 받기 (분류는 제목으로 추천해 미리 고름)
  Future<void> selectRoutine(String routineId, AppLocalizations l10n) async {
    state = TalkShareState(routineId: routineId, isPreviewLoading: true);
    try {
      final preview = await _repository.preview(routineId);
      // 받는 사이 다른 일과를 골랐거나 화면을 떠났으면 버린다
      if (!ref.mounted || state.routineId != routineId) return;
      state = TalkShareState(
        routineId: routineId,
        preview: preview,
        blurChoiceByStepId: {
          for (final step in preview.steps)
            if (step.isGuardianPhoto) step.stepId: null,
        },
        category: suggestTalkCategory(preview.title, l10n),
      );
    } catch (e) {
      if (!ref.mounted || state.routineId != routineId) return;
      state = TalkShareState(
        routineId: routineId,
        previewFailure: AppFailure.of(e),
      );
    }
  }

  /// 일과 고르기로 되돌아가기 (입력한 것은 버린다)
  void clearRoutine() => state = const TalkShareState();

  void chooseBlur(String stepId, {required bool shouldBlur}) {
    if (!state.blurChoiceByStepId.containsKey(stepId)) return;
    state = state.copyWith(
      blurChoiceByStepId: {...state.blurChoiceByStepId, stepId: shouldBlur},
    );
  }

  void setNote(String note) => state = state.copyWith(note: note);

  void setCategory(RoutineTemplateCategory category) =>
      state = state.copyWith(category: category);

  /// 올리기 > 만들어진 글 id. 성공하면 피드·인기·내가 올린 글 목록을 다시 받게 한다
  /// 실패는 [AppFailure] 로 던지고 입력은 그대로 둔다
  Future<String> submit() async {
    final routineId = state.routineId;
    final category = state.category;
    if (!state.canSubmit || routineId == null || category == null) {
      throw StateError('share is not ready');
    }
    state = state.copyWith(isSubmitting: true);
    try {
      final trimmedNote = state.note.trim();
      final postId = await _repository.create(
        routineId: routineId,
        category: category.serverValue,
        note: trimmedNote.isEmpty ? null : trimmedNote,
        blurredStepIds: state.blurredStepIds,
      );
      invalidateTalkLists(ref);
      return postId;
    } finally {
      // 성공·실패 공통: 화면이 이미 닫혔으면 건드리지 않는다
      if (ref.mounted) state = state.copyWith(isSubmitting: false);
    }
  }
}
