import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import '../config/app_config.dart';
import '../logger/app_logger.dart';
import 'app_status.dart';

/// 스토어 확인 결과: 새 버전 유무 + 하루 한 번 기록에 쓰는 새 버전 표시
class StoreUpdateCheck {
  const StoreUpdateCheck({
    required this.isUpdateAvailable,
    required this.versionLabel,
  });

  final bool isUpdateAvailable;

  /// 새 버전 표시 (iOS `2.68.0`, Android `build-412`). 새 버전이 없으면 빈 값
  final String versionLabel;
}

/// 스토어에 실제로 올라간 새 버전 확인. 확인 못 하면 null (서버 최신 버전으로 대체).
/// 테스트·시험 빌드는 가짜를 넣는다.
typedef StoreUpdateChecker = Future<StoreUpdateCheck?> Function(
  String currentVersion,
);

/// 스토어 조회 대기 상한 (5초): 홈 첫 화면 뒤에 묻지만 오래 끌면 안내가 늦게 튀어나온다
const _storeLookupTimeout = Duration(seconds: 5);

/// App Store 공개 조회 주소. 국가는 출시 국가(kr) 기준
final _appStoreLookupUrl = Uri.https('itunes.apple.com', '/lookup', {
  'id': AppConfig.iosAppStoreId,
  'country': 'kr',
});

/// 플랫폼별 스토어 확인: iOS App Store 공개 조회, Android Play 앱 내 업데이트 확인
Future<StoreUpdateCheck?> checkStoreUpdate(String currentVersion) async {
  if (currentVersion.trim().isEmpty) return null;
  try {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => await _checkAppStore(currentVersion),
      TargetPlatform.android => await _checkPlayStore(),
      _ => null,
    };
  } catch (e, st) {
    // Play 밖 설치(테스트 APK)·네트워크 실패·형식 다름: 서버 값으로 넘김
    AppLogger.error('app-status', e, st, {'step': 'checkStoreUpdate'});
    return null;
  }
}

/// App Store 판매 중 버전 <-> 지금 버전 (심사 중 버전은 조회에 안 나옴)
Future<StoreUpdateCheck?> _checkAppStore(String currentVersion) async {
  if (AppConfig.iosAppStoreId.isEmpty) return null;
  // 서버용 Dio(토큰·서버 주소)를 쓰지 않음: 인증 헤더가 Apple 로 나가면 안 됨
  final dio = Dio(BaseOptions(
    connectTimeout: _storeLookupTimeout,
    receiveTimeout: _storeLookupTimeout,
    responseType: ResponseType.plain,
  ));
  final response = await dio.getUri<String>(_appStoreLookupUrl);
  final storeVersion = _parseAppStoreVersion(response.data);
  if (storeVersion.isEmpty) return null;

  final isUpdateAvailable = AppStatus.isLower(currentVersion, storeVersion);
  return StoreUpdateCheck(
    isUpdateAvailable: isUpdateAvailable,
    versionLabel: isUpdateAvailable ? storeVersion : '',
  );
}

/// 조회 응답(text/javascript 로 오는 JSON) > `results[0].version`. 형식이 다르면 빈 값
String _parseAppStoreVersion(String? body) {
  if (body == null || body.isEmpty) return '';
  final decoded = jsonDecode(body);
  if (decoded is! Map) return '';
  final results = decoded['results'];
  if (results is! List || results.isEmpty) return '';
  final first = results.first;
  if (first is! Map) return '';
  final version = first['version'];
  return version is String ? version.trim() : '';
}

/// Play 판정 그대로 사용 (버전 비교는 Play 가 versionCode 로 함)
Future<StoreUpdateCheck?> _checkPlayStore() async {
  final info = await InAppUpdate.checkForUpdate().timeout(_storeLookupTimeout);
  final isUpdateAvailable =
      info.updateAvailability == UpdateAvailability.updateAvailable;
  return StoreUpdateCheck(
    isUpdateAvailable: isUpdateAvailable,
    // versionCode 를 못 받아도 하루 한 번 기록은 남도록 unknown 으로 둠
    versionLabel: isUpdateAvailable
        ? 'build-${info.availableVersionCode ?? 'unknown'}'
        : '',
  );
}

final storeUpdateCheckerProvider =
    Provider<StoreUpdateChecker>((ref) => checkStoreUpdate);
