import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../dev/dev_simulation.dart';
import '../l10n/l10n_context.dart';
import '../logger/app_logger.dart';
import '../storage/local_storage.dart';
import '../widgets/show_failure.dart';
import 'app_status.dart';
import 'app_status_repository.dart';
import 'store_launcher.dart';
import 'store_update_check.dart';
import 'update_suggestion_prompt.dart';

/// 스토어를 못 열었을 때 붙는 식별자 (강제 업데이트 화면과 같은 코드)
const updateStoreFailureCode = 'E-UPDATE-STORE';

/// 권유할 새 버전 표시: 강제 업데이트 대상 제외 > 스토어 확인 결과 우선 > 확인 못 했으면 서버 최신 버전. 없으면 null
/// 스토어가 새 버전 없다고 하면 서버 값이 높아도 권하지 않음 (심사 중 버전으로 보내지 않게)
String? updateSuggestionTarget({
  required AppStatus status,
  required String currentVersion,
  required StoreUpdateCheck? storeCheck,
}) {
  // 강제 업데이트 대상은 앱 상태 게이트가 화면을 막으므로 권유하지 않음
  if (status.requiresUpdate(currentVersion)) return null;
  if (storeCheck != null) {
    return storeCheck.isUpdateAvailable ? storeCheck.versionLabel : null;
  }
  return status.suggestsUpdate(currentVersion) ? status.latestVersion : null;
}

/// 업데이트 권유 판정: 권유할 새 버전이 있고, 오늘 그 버전으로 띄운 적 없음
bool shouldSuggestUpdate({
  required String? target,
  required String? lastShownRecord,
  required DateTime now,
}) {
  if (target == null) return false;
  return lastShownRecord != updateSuggestionRecord(target, now);
}

/// 표시 기록: `{최신 버전}|{yyyy-MM-dd}` (기기 날짜 기준 하루 한 번)
String updateSuggestionRecord(String latestVersion, DateTime now) {
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$latestVersion|${now.year}-$month-$day';
}

/// 보호자 홈·이룸이 홈 진입 시 업데이트 권유 (하루 한 번, 닫을 수 있음)
/// 앱 상태 > 스토어 확인 > 판정 > 기록 > 안내. 어느 단계 실패도 홈을 막지 않음 (스토어 열기 실패만 에러 코드로 알림)
Future<void> showUpdateSuggestionIfNeeded(BuildContext context, WidgetRef ref) async {
  final ({AppStatus status, String version}) result;
  try {
    result = await ref.read(appStatusProvider.future);
  } catch (_) {
    return;
  }
  // 확인 실패는 checker 안에서 null 로 바뀜 (서버 값으로 판단)
  // 개발자 도구 권유 흉내는 스토어 확인을 건너뜀 (스토어에 새 버전이 없어도 띄움)
  final storeCheck = DevSimulation.isSuggestingUpdate
      ? null
      : await ref.read(storeUpdateCheckerProvider)(result.version);
  final target = updateSuggestionTarget(
    status: result.status,
    currentVersion: result.version,
    storeCheck: storeCheck,
  );
  final storage = ref.read(localStorageProvider);
  final now = DateTime.now();
  final isNeeded = shouldSuggestUpdate(
    target: target,
    lastShownRecord: storage.updateSuggestionShownRecord,
    now: now,
  );
  if (!isNeeded || target == null || !context.mounted) return;
  // 스토어를 기다리는 사이 다른 화면·팝업으로 넘어갔으면 그 위에 띄우지 않음 (다음 진입에 다시 판단)
  if (ModalRoute.of(context)?.isCurrent == false) return;

  final storeUrl = AppConfig.storeUrl(defaultTargetPlatform, serverUrl: result.status.storeUrl);
  if (storeUrl == null) return;

  // 띄우기 전에 기록 (닫는 방법과 상관없이 오늘은 한 번)
  try {
    await storage.setUpdateSuggestionShownRecord(
      updateSuggestionRecord(target, now),
    );
  } catch (e, st) {
    AppLogger.error('app-status', e, st, {'step': 'saveUpdateSuggestion'});
  }
  if (!context.mounted) return;

  final shouldOpenStore = await showUpdateSuggestionPrompt(context);
  if (!shouldOpenStore || !context.mounted) return;
  await openStoreOrShowFailure(context, ref, storeUrl);
}

/// 스토어 열기 > 못 열면 에러 코드와 함께 알림 (강제 업데이트 화면과 권유 팝업 공통)
Future<void> openStoreOrShowFailure(BuildContext context, WidgetRef ref, Uri storeUrl) async {
  // await 뒤에서 context 를 쓰지 않도록 문구를 먼저 잡음
  final l10n = context.l10n;
  Object? error;
  var isOpened = false;
  try {
    isOpened = await ref.read(storeLauncherProvider)(storeUrl);
  } catch (e, st) {
    error = e;
    AppLogger.error('app-status', e, st, {'step': 'openStore'});
  }
  if (isOpened || !context.mounted) return;
  await showFailure(
    context,
    error,
    title: l10n.appStatusStoreOpenFailedTitle,
    fallback: l10n.appStatusStoreOpenFailedFallback,
    fallbackCode: updateStoreFailureCode,
  );
}
