import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lock_screen/home_widget_bridge.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/storage/card_image_disk_cache.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';
import '../../child/application/child_routine_notifier.dart';
import '../../guardian/application/home_routines.dart';
import '../../guardian/application/routine_providers.dart';
import '../../member/application/elumi_streak_providers.dart';
import '../../member/application/member_providers.dart';
import '../../reminder/application/routine_reminder_controller.dart';
import '../data/bundled_card_art_file.dart';
import '../domain/lock_screen_snapshot_builder.dart';
import 'lock_screen_providers.dart';

/// 지금 홈 목록 > 잠금화면·iOS 위젯 요약 (그림 파일 경로 없음, [pushLockScreenSnapshot] 이 채움)
/// 보호자: 홈 오늘 일과 · 이룸이 기기: 이룸이에게 보이는 오늘 일과
final lockScreenSnapshotProvider = Provider<LockScreenSnapshot>((ref) {
  final mode = ref.watch(lockScreenDeviceModeProvider);
  final childProgress = ref.watch(childRoutineProvider);
  final reminders = ref.watch(routineReminderProvider);
  final routines = mode == LockScreenMode.guardian
      ? ref.watch(homeRoutinesProvider)
      : _elumiVisibleRoutines(ref.watch(todayRoutinesProvider).value);
  final reminderTimeByRoutineId = <String, RoutineClockTime>{
    for (final routine in routines)
      if (reminders[routine.id] ?? reminders[routine.sourceRoutineId] case final reminder?)
        routine.id: (hour: reminder.hour, minute: reminder.minute),
  };
  final member = ref.watch(memberProvider).value;
  return LockScreenSnapshotBuilder.build(
    mode: mode,
    routines: routines,
    isCardDone: (routine, card) => _isCardDone(routine, card, childProgress),
    reminderTimeByRoutineId: reminderTimeByRoutineId,
    now: DateTime.now(),
  ).copyWithWidgetExtras(
    // 위젯 머리 이름 · 별과 연속 (회원 정보를 못 받았으면 0)
    elumiName: ref.watch(localStorageProvider).nickname,
    streakDays: ref.watch(elumiStreakProvider).days,
    starCount: member?.totalStars ?? 0,
  );
});

/// 이룸이 화면과 같은 기준: 승인한(보낸) 일과 중 카드가 있는 것만
List<Routine> _elumiVisibleRoutines(List<Routine>? fetched) => [
  ...?fetched?.where(
    (routine) => routine.isVisibleToChild && routine.steps.isNotEmpty,
  ),
];

// 진행률과 같은 기준: 못 보낸 체크가 있는 일과(로컬 일과 포함)는 기기 기록, 아니면 서버 값
bool _isCardDone(Routine routine, ActionCard card, ChildRoutineState progress) {
  final isLocalOnly = routine.id.isEmpty || routine.id == 'local';
  final useLocal = isLocalOnly || progress.pending.contains(routine.id);
  return useLocal ? progress.isChecked(routine.id, card) : card.completed;
}

/// 요약 저장: 이룸이 카드 그림 파일 찾기(받아 둔 것만) > 잠금화면(Android)·홈 위젯(iOS) 채널로 보냄
/// 같은 값이면 채널이 건너뜀. 실패해도 화면은 그대로 (로그만)
Future<void> pushLockScreenSnapshot(
  Ref ref,
  LockScreenSnapshot snapshot,
) async {
  try {
    final completeSnapshot = await _withCardImageFile(ref, snapshot);
    await ref.read(lockScreenBridgeProvider).updateSnapshot(completeSnapshot);
    // iOS 위젯: 보호자·이룸이 기기 모두 (위젯 3종이 mode 로 문구를 고름, #1465)
    await ref.read(homeWidgetBridgeProvider).updateSnapshot(completeSnapshot);
  } catch (error, stackTrace) {
    AppLogger.error('lock screen snapshot', error, stackTrace);
  }
}

/// 이룸이 카드 그림 파일: 받아 둔 그림 > 없으면 번들 예시·픽토그램 파일 (잠금화면·위젯은 네트워크를 쓰지 않음)
Future<LockScreenSnapshot> _withCardImageFile(
  Ref ref,
  LockScreenSnapshot snapshot,
) async {
  final card = snapshot.elumiCard;
  if (card == null) return snapshot;
  final routine = ref
      .read(todayRoutinesProvider)
      .value
      ?.where((routine) => routine.id == card.routineId)
      .firstOrNull;
  Future<String?> filePathOf(String cardId, String? exampleImageId, String? pictogramId) async {
    final imagePath = routine?.steps.where((step) => step.id == cardId).firstOrNull?.imagePath;
    // 올린 그림 없음 > 예시 그림·픽토그램을 위젯이 읽을 파일로 (#1465)
    if (imagePath == null || imagePath.isEmpty) {
      return ref.read(bundledCardArtFileProvider).filePathOf(exampleImageId: exampleImageId, pictogramId: pictogramId);
    }
    return ref.read(cardImageDiskCacheProvider).existingFilePath(imagePath);
  }

  // 지금 카드 + 위젯이 체크 뒤 넘겨 볼 다음 카드 (2단계)
  final currentPath = await filePathOf(card.cardId, card.exampleImageId, card.pictogramId);
  final upcomingCards = [
    for (final upcoming in card.upcomingCards)
      upcoming.copyWithImageFilePath(
        await filePathOf(upcoming.cardId, upcoming.exampleImageId, upcoming.pictogramId),
      ),
  ];
  return snapshot.copyWithElumiCard(card.copyWithImageFilePath(currentPath).copyWithUpcomingCards(upcomingCards));
}

/// 요약 보내기 함수 (홈이 떠 있는 동안 LockScreenSnapshotSync 가 바뀔 때마다 부름)
final lockScreenSnapshotPusherProvider =
    Provider<void Function(LockScreenSnapshot snapshot)>(
      (ref) =>
          (snapshot) => unawaited(pushLockScreenSnapshot(ref, snapshot)),
    );
