import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../storage/installation_store.dart';
import 'app_log_buffer.dart';

/// 첨부 기록 머리글의 "진단" 구역: 설치 경로, 서명 해시, 기기, 연결, 카카오 로그인 환경
///
/// 값마다 따로 읽고 실패하면 '-' (한 값이 실패해도 의견 전송과 나머지 값은 막지 않는다).
/// IMEI·시리얼·광고 ID 같은 기기 하드웨어 식별자는 읽지 않는다.
class AppLogDiagnostics {
  AppLogDiagnostics({
    MethodChannel channel = const MethodChannel(channelName),
    InstallationStore installationStore = const InstallationStore(),
    Future<String> Function()? readKakaoKeyHash,
    Future<List<ConnectivityResult>> Function()? readConnectivity,
    Future<String> Function()? readDeviceModel,
  }) : _channel = channel,
       _installationStore = installationStore,
       _readKakaoKeyHash = readKakaoKeyHash ?? (() async => KakaoSdk.platformInfo.origin),
       _readConnectivity =
           readConnectivity ?? (() => Connectivity().checkConnectivity()),
       _readDeviceModel = readDeviceModel ?? _readDeviceModelFromPlugin;

  /// MainActivity 가 등록하는 네이티브 채널 (AppDiagnosticsChannel.kt)
  static const channelName = 'elum/diagnostics';

  /// 앱 시작 시각. AppDiagnostics.install 이 기록한다.
  static DateTime? startedAt;

  /// 카카오 로그인 오류 기록을 찾을 때 쓰는 머리글 (AppLogger 의 카테고리와 같다)
  static const socialLoginErrorKeyword = '소셜 로그인';
  static const _maxSocialLoginErrorChars = 240;

  final MethodChannel _channel;
  final InstallationStore _installationStore;
  final Future<String> Function() _readKakaoKeyHash;
  final Future<List<ConnectivityResult>> Function() _readConnectivity;
  final Future<String> Function() _readDeviceModel;

  Future<String> buildSection() async {
    final native = await _readNative();
    final lines = <String>[
      '== 진단 ==',
      '설치 경로: ${_installerLabel(native)}',
      '서명 키 해시: ${_signingKeyHashes(native)}',
      '설치 식별자: ${await _safe(_installationStore.load)}',
      '기기: ${await _safe(_readDeviceModel)}',
      '시간대: ${_safeSync(_timeZoneLabel)}',
      '연결: ${await _safe(_connectivityLabel)}',
      '빌드: ${_buildKind()}',
      '앱 실행 시간: ${_safeSync(_uptimeLabel)}',
      '저전력 모드: ${_boolLabel(native['isPowerSaveMode'])}',
      '남은 저장 공간: ${_storageLabel(native['freeStorageBytes'])}',
      '카카오톡: ${_kakaoTalkLabel(native)}',
      '카카오 SDK 키 해시: ${await _safe(_readKakaoKeyHash)}',
      '마지막 소셜 로그인 오류: ${_safeSync(_lastSocialLoginError)}',
    ];
    return lines.join('\n');
  }

  Future<Map<String, Object?>> _readNative() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('getDiagnostics');
      return raw ?? const {};
    } catch (_) {
      return const {};
    }
  }

  static Future<String> _readDeviceModelFromPlugin() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return '${info.manufacturer} ${info.model} (Android ${info.version.release}, SDK ${info.version.sdkInt})';
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return '${info.utsname.machine} (iOS ${info.systemVersion}, ${info.isPhysicalDevice ? '실기기' : '시뮬레이터'})';
    }
    return '-';
  }

  Future<String> _connectivityLabel() async {
    final results = await _readConnectivity();
    return results.isEmpty ? 'none' : results.map((r) => r.name).join(',');
  }

  // Play 설치는 com.android.vending, 직접 설치(APK 공유, adb)는 빈 값
  String _installerLabel(Map<String, Object?> native) {
    final installer = native['installerPackage'];
    if (installer is! String) return '-';
    return switch (installer) {
      'com.android.vending' => 'Play 스토어',
      '' => '직접 설치 (스토어 아님)',
      final other => other,
    };
  }

  String _signingKeyHashes(Map<String, Object?> native) {
    final hashes = native['signingKeyHashes'];
    if (hashes is! List || hashes.isEmpty) return '-';
    return hashes.join(', ');
  }

  String _kakaoTalkLabel(Map<String, Object?> native) {
    final version = native['kakaoTalkVersion'];
    if (version is! String) return '-';
    return version.isEmpty ? '미설치' : version;
  }

  String _boolLabel(Object? value) => value is bool ? (value ? '예' : '아니오') : '-';

  String _storageLabel(Object? bytes) {
    if (bytes is! int) return '-';
    return '${(bytes / (1024 * 1024)).round()}MB';
  }

  String _timeZoneLabel() {
    final now = DateTime.now();
    return '${now.timeZoneName} (UTC${now.timeZoneOffset.isNegative ? '-' : '+'}'
        '${now.timeZoneOffset.inHours.abs()}), 지역 ${PlatformDispatcher.instance.locale.countryCode ?? '-'}';
  }

  String _buildKind() => kReleaseMode ? '릴리스' : (kProfileMode ? '프로필' : '디버그');

  String _uptimeLabel() {
    final started = startedAt;
    if (started == null) return '-';
    return '${DateTime.now().difference(started).inSeconds}초';
  }

  String _lastSocialLoginError() {
    final error = AppLogBuffer.lastErrorContaining(socialLoginErrorKeyword);
    if (error == null) return '없음';
    final oneLine = error.replaceAll(RegExp(r'\s+'), ' ');
    return oneLine.length <= _maxSocialLoginErrorChars
        ? oneLine
        : oneLine.substring(0, _maxSocialLoginErrorChars);
  }

  Future<String> _safe(Future<String> Function() read) async {
    try {
      final value = await read();
      return value.isEmpty ? '-' : value;
    } catch (_) {
      return '-';
    }
  }

  String _safeSync(String Function() read) {
    try {
      final value = read();
      return value.isEmpty ? '-' : value;
    } catch (_) {
      return '-';
    }
  }
}
