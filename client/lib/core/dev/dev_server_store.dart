import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../logger/app_logger.dart';

/// 테스트 계정 한 건 (서버 주소별로 저장)
class DevTestAccount {
  const DevTestAccount({
    required this.username,
    required this.password,
    required this.createdAt,
  });

  final String username;
  final String password;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'username': username,
    'password': password,
    'createdAt': createdAt.toIso8601String(),
  };

  /// 깨진 항목이면 null (그 항목만 버림)
  static DevTestAccount? fromJson(Object? json) {
    if (json is! Map) return null;
    final username = json['username'];
    final password = json['password'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (username is! String || password is! String || createdAt == null) return null;
    return DevTestAccount(username: username, password: password, createdAt: createdAt);
  }
}

/// 개발자 도구 서버 설정 저장: 지정 주소, 최근 주소, 서버별 테스트 계정
/// 앱 저장값([LocalStorage])과 키를 나눠 둔다 (로그아웃·회원삭제의 clearAll 이 지우지 않음)
/// 비밀번호 평문 저장: 테스트 서버 일회용 계정, 개발자 도구 빌드에만 있음
class DevServerStore {
  DevServerStore(this._prefs);

  final SharedPreferences _prefs;

  // 개발자 도구에서 고른 API 주소 (없으면 .env 기본 주소)
  static const _apiBaseUrlKey = 'dev.apiBaseUrl';
  // 최근 쓴 주소 목록 (JSON 배열, 최신 먼저)
  static const _recentApiBaseUrlsKey = 'dev.recentApiBaseUrls';
  // 서버 주소 > 테스트 계정 목록 (JSON 맵)
  static const _testAccountsKey = 'dev.testAccountsByServer';
  static const _maximumRecentUrlCount = 5;

  static Future<DevServerStore> open() async =>
      DevServerStore(await SharedPreferences.getInstance());

  /// 시작 때 한 번: 저장한 주소를 [AppConfig] 에 넣음 (개발자 도구가 꺼진 빌드는 AppConfig 가 무시)
  static Future<void> applySavedApiBaseUrl() async {
    if (!AppConfig.showDevTools) return;
    try {
      final store = await open();
      AppConfig.overrideApiBaseUrl(store.savedApiBaseUrl);
    } catch (e, st) {
      // 못 읽으면 기본 주소로 뜬다
      AppLogger.error('dev server', e, st, {'step': 'applySaved'});
    }
  }

  String? get savedApiBaseUrl => _prefs.getString(_apiBaseUrlKey);

  /// 주소 저장 (null 이면 기본 주소로). 직접 고른 주소는 최근 목록 맨 앞에
  Future<void> saveApiBaseUrl(String? url) async {
    if (url == null) {
      await _prefs.remove(_apiBaseUrlKey);
      return;
    }
    await _prefs.setString(_apiBaseUrlKey, url);
    final recent = [url, ...recentApiBaseUrls.where((saved) => saved != url)];
    await _prefs.setString(
      _recentApiBaseUrlsKey,
      jsonEncode(recent.take(_maximumRecentUrlCount).toList()),
    );
  }

  List<String> get recentApiBaseUrls {
    final decoded = _decode(_prefs.getString(_recentApiBaseUrlsKey));
    return decoded is List ? decoded.whereType<String>().toList() : const [];
  }

  /// [serverUrl] 에 만든 테스트 계정 (최신 먼저)
  List<DevTestAccount> testAccountsFor(String serverUrl) {
    final raw = _testAccountsByServer()[serverUrl];
    if (raw is! List) return const [];
    final accounts = [for (final entry in raw) ?DevTestAccount.fromJson(entry)];
    accounts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return accounts;
  }

  Future<void> addTestAccount(String serverUrl, DevTestAccount account) async {
    final byServer = _testAccountsByServer();
    final accounts = testAccountsFor(serverUrl)
        .where((saved) => saved.username != account.username)
        .toList();
    byServer[serverUrl] = [account, ...accounts].map((a) => a.toJson()).toList();
    await _prefs.setString(_testAccountsKey, jsonEncode(byServer));
  }

  Future<void> removeTestAccount(String serverUrl, String username) async {
    final byServer = _testAccountsByServer();
    byServer[serverUrl] = testAccountsFor(serverUrl)
        .where((saved) => saved.username != username)
        .map((a) => a.toJson())
        .toList();
    await _prefs.setString(_testAccountsKey, jsonEncode(byServer));
  }

  Map<String, Object?> _testAccountsByServer() {
    final decoded = _decode(_prefs.getString(_testAccountsKey));
    return decoded is Map ? Map<String, Object?>.from(decoded) : <String, Object?>{};
  }

  // 깨진 JSON 은 비어 있는 것으로
  static Object? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

/// 직접 입력한 주소 검사: 통과하면 끝 `/` 를 뗀 주소, 아니면 거부 사유
({String? url, String? rejectReason}) normalizeDevApiBaseUrl(String input) {
  final trimmed = input.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return (url: null, rejectReason: 'http:// 또는 https:// 로 시작해야 합니다');
  }
  if (uri.host.isEmpty) {
    return (url: null, rejectReason: '호스트가 없습니다 (예: http://192.168.0.10:8080)');
  }
  if (uri.path.isNotEmpty || uri.hasQuery || uri.hasFragment) {
    return (url: null, rejectReason: '경로 없이 주소만 넣습니다 (/api 는 앱이 붙임)');
  }
  return (url: trimmed, rejectReason: null);
}
