import 'dart:io';

import '../config/client_tuning.dart';

/// 앱이 시작할 때 서버에 묻는 것 (이슈 #279).
///
/// 점검 중인지, 이 버전으로 계속 써도 되는지를 담는다.
class AppStatus {
  const AppStatus({
    this.maintenance = false,
    this.maintenanceMessage = '',
    this.minVersion = '',
    this.latestVersion = '',
    this.storeUrl = '',
    this.tuning,
  });

  final bool maintenance;
  final String maintenanceMessage;

  /// 이 버전 미만이면 업데이트해야 쓸 수 있다. 비어 있으면 막지 않는다.
  final String minVersion;

  /// 이 버전 미만이면 업데이트를 권한다. 건너뛸 수 있다.
  final String latestVersion;

  /// 강제 업데이트 화면이 열 스토어 주소 (#416). 비어 있으면 앱에 넣어 둔 주소를 쓴다.
  /// 스토어 주소인지는 여기서 보지 않는다 — 여는 쪽([AppConfig.storeUrl])이 거른다.
  final String storeUrl;

  /// 서버가 준 대기·연출 시간값. 옛 서버라 없으면 null 이고, 그때는 지금 값을 그대로 쓴다.
  final ClientTuning? tuning;

  /// 서버가 못 오거나 형식이 다를 때 쓰는 값.
  ///
  /// **아무것도 막지 않는다.** 서버를 못 봤다는 이유로 앱을 세우면,
  /// 정작 서버가 죽었을 때 아무도 앱을 열지 못한다.
  static const unknown = AppStatus();

  /// 플랫폼에 맞는 값만 꺼낸다. 형식이 달라도 예외를 던지지 않는다 —
  /// 이 응답 하나 때문에 앱이 못 뜨면 안 된다.
  factory AppStatus.fromJson(Map<String, dynamic> json) {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final version = json[platform];
    return AppStatus(
      maintenance: json['maintenance'] == true,
      maintenanceMessage: (json['maintenanceMessage'] as String?)?.trim() ?? '',
      minVersion: version is Map
          ? (version['minVersion'] as String?)?.trim() ?? ''
          : '',
      latestVersion: version is Map
          ? (version['latestVersion'] as String?)?.trim() ?? ''
          : '',
      // 문자열이 아니면(형식이 다름) 빈 값으로 둔다 — 캐스팅 예외로 앱이 멈추면 안 된다
      storeUrl: version is Map && version['storeUrl'] is String
          ? (version['storeUrl'] as String).trim()
          : '',
      tuning: ClientTuning.tryParse(json['client']),
    );
  }

  /// 지금 버전이 최소치에 못 미치는가 (업데이트해야 쓸 수 있다).
  bool requiresUpdate(String current) => isLower(current, minVersion);

  /// 지금 버전이 최신보다 낮은가 (권하되 건너뛸 수 있다).
  bool suggestsUpdate(String current) => isLower(current, latestVersion);

  /// `a`가 `b`보다 낮은가.
  ///
  /// **문자열로 견주지 않는다.** `'1.10.0' < '1.9.0'` 이 참이 되어
  /// 최신 버전을 쓰는 사람에게 업데이트를 요구하게 된다.
  ///
  /// 기준이 비어 있거나 숫자로 읽히지 않으면 **막지 않는다** — 설정이 잘못됐다고
  /// 사용자를 세우는 쪽이 더 나쁘다.
  static bool isLower(String a, String b) {
    if (a.trim().isEmpty || b.trim().isEmpty) return false;
    final left = _parse(a);
    final right = _parse(b);
    if (left.isEmpty || right.isEmpty) return false;

    for (var i = 0; i < 3; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l < r;
    }
    return false;
  }

  /// `1.2.3+45` · `v1.2.3` 처럼 뒤에 붙는 것들을 떼고 숫자만 본다.
  static List<int> _parse(String raw) {
    final core = raw.trim().replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[+\-\s]')).first;
    final parts = core.split('.');
    final out = <int>[];
    for (final p in parts.take(3)) {
      final n = int.tryParse(p);
      if (n == null) return const [];
      out.add(n);
    }
    return out;
  }
}
