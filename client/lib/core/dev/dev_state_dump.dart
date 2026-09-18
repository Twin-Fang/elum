import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'dev_log_file.dart';

/// 앱 내부 상태를 통째로 글로 뽑는다 (이슈 #219).
///
/// QA·프론트가 문제를 만났을 때 **그 자리에서 전부 넘길 수 있게** 하는 것이 목적이다.
/// 화면만 캡처해서는 어떤 값이 들어 있었는지 알 수 없다.
///
/// ## ⚠️ 토큰·PIN을 가린 채로 담지 않는다
///
/// 가리면 정작 인증 문제를 못 쫓는다. **테스트 단계 전용 기능**이고, 정식 출시 전에
/// 개발자 도구와 함께 통째로 제거한다 (이슈 #13). 그때까지는 빠짐없이 담는다.
///
/// ## 한 항목이 실패해도 나머지는 나온다
///
/// 덤프는 문제가 생겼을 때 쓰는 도구다. 여기서 예외가 나면 **정작 필요한 순간에
/// 아무것도 못 얻는다.** 항목마다 따로 감싸 실패한 칸만 사유를 적는다.
abstract final class DevStateDump {
  /// 로그를 뺀 요약. 화면에 바로 보여줄 때 쓴다.
  static Future<String> summary(BuildContext? context) async {
    final b = StringBuffer();
    _section(b, '앱', () => _app());
    _section(b, '기기', () => _device(context));
    _section(b, '설정', () => _config());
    await _sectionAsync(b, '저장값', _storage);
    await _sectionAsync(b, '세션', _session);
    _section(b, '화면', () => _route(context));
    return b.toString();
  }

  /// 요약 + 로그 파일 전체. 내보내기·복사에 쓴다.
  static Future<String> full(BuildContext? context) async {
    final head = await summary(context);
    String log;
    try {
      log = await DevLogFile.readAll();
    } catch (e) {
      log = '(로그를 읽지 못했습니다: $e)';
    }
    return '$head\n'
        '════════ 로그 (${_kb(DevLogFile.sizeBytes.value)}) ════════\n'
        '$log';
  }

  /// 파일명. 언제 뽑은 것인지 파일만 봐도 알게 한다.
  static String fileName() {
    final n = DateTime.now();
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return 'elum-debug-${n.year}${p(n.month)}${p(n.day)}'
        '-${p(n.hour)}${p(n.minute)}${p(n.second)}.log';
  }

  // ── 항목별 수집 ──────────────────────────────────────────────

  static Map<String, String> _app() => {
        '패키지': 'kr.twinfang.elum',
        '빌드 모드': kReleaseMode
            ? 'release'
            : kProfileMode
                ? 'profile'
                : 'debug',
        'ELUM_BUILD': AppConfig.isDevBuild ? 'dev' : 'prod',
        '뽑은 시각': DateTime.now().toIso8601String(),
      };

  static Map<String, String> _device(BuildContext? context) {
    final m = <String, String>{
      'OS': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      '로케일': PlatformDispatcher.instance.locale.toString(),
    };
    if (context == null) return m;
    final mq = MediaQuery.of(context);
    m.addAll({
      '화면': '${mq.size.width.toStringAsFixed(1)} × ${mq.size.height.toStringAsFixed(1)}',
      'DPR': mq.devicePixelRatio.toStringAsFixed(2),
      '글꼴 배율': mq.textScaler.scale(14).toStringAsFixed(2),
      '다크모드': '${mq.platformBrightness == Brightness.dark}',
      '동작 줄이기': '${mq.disableAnimations}',
      '안전영역': '상 ${mq.padding.top.toStringAsFixed(0)} / 하 ${mq.padding.bottom.toStringAsFixed(0)}',
      '키보드': mq.viewInsets.bottom.toStringAsFixed(0),
    });
    return m;
  }

  static Map<String, String> _config() => {
        'API 주소': AppConfig.apiBaseUrl,
        '연결 타임아웃': '${AppConfig.connectTimeout.inMilliseconds}ms',
        '수신 타임아웃': '${AppConfig.receiveTimeout.inMilliseconds}ms',
        'TTS 주소': AppConfig.ttsBaseUrl,
        'DLP 최소 연출': '${AppConfig.dlpMinDelay.inMilliseconds}ms',
        '개발자 도구': '${AppConfig.showDevTools}',
        '온보딩 건너뛰기': '${AppConfig.skipOnboarding}',
        '네트워크 로그': '${AppConfig.enableNetworkLog}',
        'mock 사용': '${AppConfig.useMock}',
      };

  /// SharedPreferences에 실제로 들어 있는 **모든 키**를 읽는다.
  ///
  /// 코드가 아는 키만 나열하면 새 키가 늘 때마다 여기도 고쳐야 하고, 빠뜨리면
  /// 정작 그 값이 궁금할 때 안 보인다. 저장소가 가진 것을 그대로 훑는다.
  static Future<Map<String, String>> _storage() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList()..sort();
    if (keys.isEmpty) return {'(비어 있음)': ''};
    return {for (final k in keys) k: '${prefs.get(k)}'};
  }

  /// 토큰은 **전문 그대로** 담는다 (위 주석 참조).
  static Future<Map<String, String>> _session() async {
    final store = SecureTokenStore();
    await store.load();
    return {
      '세션 있음': '${store.hasSession}',
      'accessToken': store.accessToken ?? '(없음)',
      'refreshToken': store.refreshToken ?? '(없음)',
    };
  }

  static Map<String, String> _route(BuildContext? context) {
    if (context == null) return {'(context 없음)': ''};
    final r = ModalRoute.of(context)?.settings.name;
    return {'현재 라우트': r ?? '(이름 없음)'};
  }

  // ── 조립 ─────────────────────────────────────────────────────

  static void _section(
    StringBuffer b,
    String title,
    Map<String, String> Function() collect,
  ) {
    b.writeln('════════ $title ════════');
    try {
      _write(b, collect());
    } catch (e) {
      b.writeln('  (수집 실패: $e)');
    }
    b.writeln();
  }

  static Future<void> _sectionAsync(
    StringBuffer b,
    String title,
    Future<Map<String, String>> Function() collect,
  ) async {
    b.writeln('════════ $title ════════');
    try {
      _write(b, await collect());
    } catch (e) {
      b.writeln('  (수집 실패: $e)');
    }
    b.writeln();
  }

  static void _write(StringBuffer b, Map<String, String> m) {
    if (m.isEmpty) {
      b.writeln('  (없음)');
      return;
    }
    final pad = m.keys.map((k) => k.length).reduce((a, c) => a > c ? a : c);
    for (final e in m.entries) {
      b.writeln('  ${e.key.padRight(pad)} : ${e.value}');
    }
  }

  static String _kb(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';

  /// UI가 같은 표기를 쓰도록 공개한다.
  static String formatBytes(int bytes) => _kb(bytes);
}
