import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';
import 'app_status_repository.dart';

/// 서버 Pro 판매 스위치 (#1132): 이번 응답 값 > 지난 저장값 > false (판매 끔)
///
/// 앱 상태를 다시 받을 때마다(실행·재개) 바뀐다. 빌드 설정·이룸이 기기 판정은 부르는 쪽 몫
final isServerStoreSellingOpenProvider = Provider<bool>((ref) {
  final isOpenFromServer = ref.watch(
    appStatusProvider.select((check) => check.value?.status.isStoreSellingOpen),
  );
  if (isOpenFromServer != null) return isOpenFromServer;
  return ref.watch(localStorageProvider).isCachedStoreSellingOpen ?? false;
});

/// 서버가 준 판매 값을 다음 실행용으로 저장 (응답을 못 받았으면 null > 저장값 유지)
///
/// 저장 실패는 이번 실행만 새 값으로 돎 (다음 응답 때 다시 저장)
void cacheServerStoreSelling(bool? isOpenFromServer, {required LocalStorage storage}) {
  if (isOpenFromServer == null) return;
  if (storage.isCachedStoreSellingOpen == isOpenFromServer) return;
  void warn(Object error) => debugPrint('[store selling] cache failed — this run only: $error');
  // 동기 예외·실패한 Future 둘 다 잡음
  try {
    unawaited(storage.setCachedStoreSellingOpen(isOpenFromServer).catchError(warn));
  } catch (error) {
    warn(error);
  }
}
