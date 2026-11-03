import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import '../logger/app_logger.dart';

/// Play 앱 내 업데이트 시도 결과: 처리됨(완료·사용자 취소), 쓸 수 없음(스토어로 대체)
enum PlayInAppUpdateOutcome { handled, unavailable }

typedef PlayInAppUpdateStarter = Future<PlayInAppUpdateOutcome> Function();

/// 새 버전 확인 대기 상한 (5초): 버튼을 누른 뒤라 오래 기다리게 하지 않음
const _updateLookupTimeout = Duration(seconds: 5);

/// Android 즉시 업데이트: 새 버전 확인 > Play 전체 화면 업데이트 (완료 시 앱 재시작)
/// iOS·Play 밖 설치·실패는 unavailable. 유연 업데이트는 쓰는 도중 재시작될 수 있어 제외 (#1047)
Future<PlayInAppUpdateOutcome> startPlayInAppUpdate() async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return PlayInAppUpdateOutcome.unavailable;
  }
  try {
    final updateInfo =
        await InAppUpdate.checkForUpdate().timeout(_updateLookupTimeout);
    if (!_canStartImmediateUpdate(updateInfo)) {
      return PlayInAppUpdateOutcome.unavailable;
    }
    final updateResult = await InAppUpdate.performImmediateUpdate();
    return updateResult == AppUpdateResult.inAppUpdateFailed
        ? PlayInAppUpdateOutcome.unavailable
        : PlayInAppUpdateOutcome.handled;
  } catch (e, st) {
    // Play 밖 설치(테스트 APK)·Play 서비스 오류: 스토어 열기로 넘김
    AppLogger.error('app-status', e, st, {'step': 'startPlayInAppUpdate'});
    return PlayInAppUpdateOutcome.unavailable;
  }
}

// 중단된 업데이트(developerTriggered…)는 즉시 업데이트로 이어서 진행
bool _canStartImmediateUpdate(AppUpdateInfo updateInfo) {
  if (updateInfo.updateAvailability ==
      UpdateAvailability.developerTriggeredUpdateInProgress) {
    return true;
  }
  return updateInfo.updateAvailability == UpdateAvailability.updateAvailable &&
      updateInfo.immediateUpdateAllowed;
}

final playInAppUpdateStarterProvider =
    Provider<PlayInAppUpdateStarter>((ref) => startPlayInAppUpdate);
