import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../l10n/l10n_context.dart';
import '../logger/app_logger.dart';
import '../storage/local_storage.dart';
import '../widgets/elum_dialog.dart';
import '../widgets/show_failure.dart';
import 'app_status.dart';
import 'app_status_repository.dart';
import 'store_launcher.dart';

/// 스토어를 못 열었을 때 붙는 식별자 (강제 업데이트 화면과 같은 코드)
const updateStoreFailureCode = 'E-UPDATE-STORE';

/// 업데이트 권유 판정: 최신 버전보다 낮고, 강제 업데이트 대상이 아니고, 오늘 이 최신 버전으로 띄운 적 없음
bool shouldSuggestUpdate({
  required AppStatus status,
  required String currentVersion,
  required String? lastShownRecord,
  required DateTime now,
}) {
  if (!status.suggestsUpdate(currentVersion)) return false;
  // 강제 업데이트 대상은 앱 상태 게이트가 화면을 막으므로 권유하지 않음
  if (status.requiresUpdate(currentVersion)) return false;
  return lastShownRecord != updateSuggestionRecord(status.latestVersion, now);
}

/// 표시 기록: `{최신 버전}|{yyyy-MM-dd}` (기기 날짜 기준 하루 한 번)
String updateSuggestionRecord(String latestVersion, DateTime now) {
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$latestVersion|${now.year}-$month-$day';
}

/// 보호자 홈 진입 시 업데이트 권유 팝업 (하루 한 번, 닫을 수 있음)
/// 상태 확인·저장·스토어 열기 실패는 홈을 막지 않음 (스토어 실패만 에러 코드로 알림)
Future<void> showUpdateSuggestionIfNeeded(BuildContext context, WidgetRef ref) async {
  final ({AppStatus status, String version}) result;
  try {
    result = await ref.read(appStatusProvider.future);
  } catch (_) {
    return;
  }
  final storage = ref.read(localStorageProvider);
  final now = DateTime.now();
  final isNeeded = shouldSuggestUpdate(
    status: result.status,
    currentVersion: result.version,
    lastShownRecord: storage.updateSuggestionShownRecord,
    now: now,
  );
  if (!isNeeded || !context.mounted) return;

  // 띄우기 전에 기록 (닫는 방법과 상관없이 오늘은 한 번)
  try {
    await storage.setUpdateSuggestionShownRecord(
      updateSuggestionRecord(result.status.latestVersion, now),
    );
  } catch (e, st) {
    AppLogger.error('app-status', e, st, {'step': 'saveUpdateSuggestion'});
  }
  if (!context.mounted) return;

  final storeUrl = AppConfig.storeUrl(defaultTargetPlatform, serverUrl: result.status.storeUrl);
  if (storeUrl == null) return;

  final l10n = context.l10n;
  final shouldOpenStore = await showElumDialog<bool>(
    context: context,
    title: l10n.updateSuggestionTitle,
    message: l10n.updateSuggestionBody,
    barrierDismissible: true,
    actions: [
      ElumDialogAction(label: l10n.updateSuggestionLater, value: false, tone: ElumDialogTone.neutral),
      ElumDialogAction(label: l10n.appStatusGoUpdate, value: true),
    ],
  );
  if (shouldOpenStore != true || !context.mounted) return;
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
