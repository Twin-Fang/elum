import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../storage/installation_store.dart';
import '../storage/token_store.dart';
import 'dev_log_file.dart';
import 'dev_state_report.dart';

/// 덤프 한 칸: 제목 + 이름·값 목록
@immutable
class DevStateSection {
  const DevStateSection(this.title, this.entries);

  final String title;
  final Map<String, String> entries;
}

/// 앱 내부 상태 칸별 수집: 앱, 화면 쪽 값(계정·요금제·흉내), 기기, 설정, 저장값, 세션 (한 칸 실패 > 그 칸만 사유)
/// 쓰는 곳 2개: 채팅 보고서([DevStateReport], 토큰 가림) · 파일 내보내기([full], 토큰 전문). 출시 전 제거 대상
abstract final class DevStateDump {
  /// 칸 모으기. [liveSections] = 화면 쪽에서 provider 로 읽은 칸 (계정·요금제·크레딧·흉내)
  static Future<List<DevStateSection>> collect({
    required BuildContext? context,
    required List<DevStateSection> liveSections,
    required bool shouldRevealTokens,
  }) async {
    return [
      await _guard('앱', _app),
      ...liveSections,
      await _guard('기기', () async => _device(context)),
      await _guard('설정', () async => _config()),
      await _guard('저장값', _storage),
      await _guard('세션', () => _session(shouldRevealTokens: shouldRevealTokens)),
    ];
  }

  /// 화면에 보여줄 글 (로그 제외, 토큰 전문)
  static Future<String> summary({required BuildContext? context, required List<DevStateSection> liveSections}) async {
    final sections = await collect(context: context, liveSections: liveSections, shouldRevealTokens: true);
    return _toPlainText(sections);
  }

  /// 파일 내보내기용 전체 (요약 + 로그 파일 전부, 토큰 전문)
  static Future<String> full({required BuildContext? context, required List<DevStateSection> liveSections}) async {
    final head = await summary(context: context, liveSections: liveSections);
    final log = await DevLogFile.readAll();
    return '$head\n'
        '════════ 로그 (${formatBytes(DevLogFile.sizeBytes.value)}) ════════\n'
        '$log';
  }

  /// 파일명: elum-debug-{yyyyMMdd}-{HHmmss}.log
  static String fileName() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return 'elum-debug-${now.year}${pad(now.month)}${pad(now.day)}'
        '-${pad(now.hour)}${pad(now.minute)}${pad(now.second)}.log';
  }

  /// 바이트 > 사람이 읽는 크기 (B, KB, MB)
  static String formatBytes(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';

  /// 앱 버전+빌드 번호 (예: 1.0.40+140). 못 읽으면 '-'
  static Future<String> appVersionLabel() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      return '-';
    }
  }

  // ── 칸별 수집 ──────────────────────────────────────────────

  static Future<Map<String, String>> _app() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return {
      '버전': '${packageInfo.version}+${packageInfo.buildNumber}',
      '번들 id': packageInfo.packageName,
      '빌드 모드': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      '빌드 종류': AppConfig.isDevBuild ? 'dev (테스트 빌드)' : '기본',
      '뽑은 시각': DevStateReport.formatLocalTime(DateTime.now()),
    };
  }

  static Map<String, String> _device(BuildContext? context) {
    final entries = <String, String>{
      'OS': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      '기기 언어': PlatformDispatcher.instance.locale.toLanguageTag(),
    };
    if (context == null) return entries;
    final mediaQuery = MediaQuery.of(context);
    entries.addAll({
      '화면':
          '${mediaQuery.size.width.toStringAsFixed(0)} × ${mediaQuery.size.height.toStringAsFixed(0)} '
          '@${mediaQuery.devicePixelRatio.toStringAsFixed(1)}x',
      // 1.0 = 기본 글자 크기
      '글자 크기 배율': mediaQuery.textScaler.scale(1).toStringAsFixed(2),
      '다크 모드': mediaQuery.platformBrightness == Brightness.dark ? '켜짐' : '꺼짐',
      '동작 줄이기': mediaQuery.disableAnimations ? '켜짐' : '꺼짐',
    });
    return entries;
  }

  static Map<String, String> _config() => {
    'API 주소': AppConfig.apiBaseUrl,
    'API 주소 출처': AppConfig.apiBaseUrlSource.name,
    '시간값 출처': AppConfig.tuningSource.name,
    '연결·수신 타임아웃': '${AppConfig.connectTimeout.inMilliseconds}ms · ${AppConfig.receiveTimeout.inMilliseconds}ms',
    '카드 최대 대기': '${AppConfig.loadingMaxWait.inMilliseconds}ms',
    'TTS 주소': AppConfig.ttsBaseUrl,
    '결제 화면 (빌드 설정)': AppConfig.isInAppPurchaseEnabled ? '켜짐' : '꺼짐',
    '네트워크 로그': AppConfig.enableNetworkLog ? '켜짐' : '꺼짐',
  };

  /// SharedPreferences 의 모든 키 (코드가 모르는 새 키도 빠지지 않게 저장소를 그대로 훑음)
  static Future<Map<String, String>> _storage() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys().toList()..sort();
    if (keys.isEmpty) return {'(비어 있음)': ''};
    return {for (final key in keys) key: '${preferences.get(key)}'};
  }

  /// 세션: 토큰 전문(파일) 또는 가린 값 + JWT 내용(채팅)
  static Future<Map<String, String>> _session({required bool shouldRevealTokens}) async {
    final store = SecureTokenStore(installationId: await const InstallationStore().load());
    await store.load();
    final accessToken = store.accessToken;
    final refreshToken = store.refreshToken;
    String toDisplayToken(String? token) => token == null
        ? '(없음)'
        : shouldRevealTokens
        ? token
        : DevStateReport.maskToken(token);
    return {
      '세션 있음': store.hasSession ? '예' : '아니오',
      'accessToken 내용': accessToken == null ? '(없음)' : DevStateReport.describeJwt(accessToken),
      'accessToken': toDisplayToken(accessToken),
      'refreshToken': toDisplayToken(refreshToken),
    };
  }

  // ── 조립 ─────────────────────────────────────────────────────

  /// 한 칸 수집 (실패하면 그 칸만 사유)
  static Future<DevStateSection> _guard(String title, Future<Map<String, String>> Function() read) async {
    try {
      return DevStateSection(title, await read());
    } catch (error) {
      return DevStateSection(title, {'(수집 실패)': '$error'});
    }
  }

  /// 칸 목록 > 화면·파일용 글 (════ 제목 ════ + 정렬한 이름 : 값)
  static String _toPlainText(List<DevStateSection> sections) {
    final buffer = StringBuffer();
    for (final section in sections) {
      buffer.writeln('════════ ${section.title} ════════');
      if (section.entries.isEmpty) buffer.writeln('  (없음)');
      final width = section.entries.keys.fold<int>(0, (max, key) => key.length > max ? key.length : max);
      for (final entry in section.entries.entries) {
        buffer.writeln('  ${entry.key.padRight(width)} : ${entry.value}');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
