import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../data/notification_repository.dart';
import '../domain/notification_settings.dart';

/// 알림 설정 스위치 8개: 모든 알림 받기(all) + 종류별 7개
/// all 은 "종류별이 전부 켜짐"을 뜻한다 — 켜면 전부 켜고, 끄면 전부 끔
enum NotificationSettingField {
  all,
  routineCompleted,
  routineSent,
  coGuardianJoined,
  creditRefilled,
  feedbackResolved,
  talkCommented,
  talkImported;

  /// 종류별 7개 (all 제외)
  static final types = values.where((field) => field != all).toList();
}

extension NotificationSettingFieldValue on NotificationSettings {
  /// 저장된 값 그대로
  bool _storedValueOf(NotificationSettingField field) => switch (field) {
        NotificationSettingField.all => isAllEnabled,
        NotificationSettingField.routineCompleted => isRoutineCompletedEnabled,
        NotificationSettingField.routineSent => isRoutineSentEnabled,
        NotificationSettingField.coGuardianJoined => isCoGuardianJoinedEnabled,
        NotificationSettingField.creditRefilled => isCreditRefilledEnabled,
        NotificationSettingField.feedbackResolved => isFeedbackResolvedEnabled,
        NotificationSettingField.talkCommented => isTalkCommentedEnabled,
        NotificationSettingField.talkImported => isTalkImportedEnabled,
      };

  /// 화면에 보일 스위치 값 (서버 allEnabled 가 꺼져 있으면 실제로 푸시가 없으므로 전부 꺼짐)
  /// all: 종류별 7개가 전부 켜졌을 때만 켜짐
  bool valueOf(NotificationSettingField field) {
    if (!isAllEnabled) return false;
    if (field != NotificationSettingField.all) return _storedValueOf(field);
    return NotificationSettingField.types.every(_storedValueOf);
  }

  /// 스위치 하나 > 저장할 값 (allEnabled = 종류별 중 하나라도 켜짐)
  /// all: 종류별 7개를 한꺼번에 같은 값으로
  NotificationSettings withValue(NotificationSettingField field, bool isOn) {
    bool nextValueOf(NotificationSettingField type) =>
        field == NotificationSettingField.all || field == type ? isOn : valueOf(type);
    return NotificationSettings(
      isAllEnabled: NotificationSettingField.types.any(nextValueOf),
      isRoutineCompletedEnabled: nextValueOf(NotificationSettingField.routineCompleted),
      isRoutineSentEnabled: nextValueOf(NotificationSettingField.routineSent),
      isCoGuardianJoinedEnabled: nextValueOf(NotificationSettingField.coGuardianJoined),
      isCreditRefilledEnabled: nextValueOf(NotificationSettingField.creditRefilled),
      isFeedbackResolvedEnabled: nextValueOf(NotificationSettingField.feedbackResolved),
      isTalkCommentedEnabled: nextValueOf(NotificationSettingField.talkCommented),
      isTalkImportedEnabled: nextValueOf(NotificationSettingField.talkImported),
    );
  }
}

final notificationSettingsControllerProvider = AsyncNotifierProvider.autoDispose<
    NotificationSettingsController, NotificationSettings>(
  NotificationSettingsController.new,
);

/// 알림 설정: 불러오기, 스위치 즉시 반영 + 저장 (실패 시 서버 확정값으로 복원)
class NotificationSettingsController extends AsyncNotifier<NotificationSettings> {
  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  /// 서버가 마지막으로 확정한 값 (실패 복원 기준)
  NotificationSettings? _confirmed;

  /// 저장 요청 진행 중 여부 (겹쳐 보내지 않음)
  bool _isSaving = false;

  @override
  Future<NotificationSettings> build() async {
    final loaded = await _repository.fetchSettings();
    _confirmed = loaded;
    return loaded;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    final refreshedState = await AsyncValue.guard(build);
    if (!ref.mounted) return;
    state = refreshedState;
  }

  /// 화면 먼저 바꾸고 저장. 실패하면 서버 확정값으로 되돌리고 그 오류를 반환 (성공·중복 호출은 null)
  /// 저장 중 들어온 토글은 화면 값만 바꿔 두고, 진행 중 요청이 끝난 뒤 최신 값으로 한 번 더 저장
  Future<Object?> toggle(NotificationSettingField field, bool isOn) async {
    final current = state.value;
    if (current == null) return null;
    state = AsyncData(current.withValue(field, isOn));
    if (_isSaving) return null;

    _isSaving = true;
    try {
      // 화면 값 <-> 서버 확정값이 같아질 때까지 (마지막 요청만 반영)
      while (state.value != _confirmed) {
        // 저장 중 다시 받기(reload)로 값이 비면 멈춤 — 새로 받은 값이 화면에 들어온다
        final desired = state.value;
        if (desired == null) return null;
        final saved = await _repository.saveSettings(desired);
        _confirmed = saved;
        if (!ref.mounted) return null;
        // 서버가 다른 값을 돌려줘도 같은 값을 다시 보내며 맴돌지 않게 맞춤
        if (state.value == desired) state = AsyncData(saved);
      }
      return null;
    } catch (e, st) {
      AppLogger.error('notification', e, st, {'step': 'saveSettings'});
      final confirmed = _confirmed;
      if (ref.mounted && confirmed != null) state = AsyncData(confirmed);
      return e;
    } finally {
      _isSaving = false;
    }
  }
}
