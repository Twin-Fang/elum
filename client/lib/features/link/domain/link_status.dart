/// 연결된 이룸이 휴대폰 하나.
class LinkedDevice {
  const LinkedDevice({required this.linkId, required this.linkedAt});

  final String linkId;
  final DateTime? linkedAt;

  static LinkedDevice? fromJson(Map<String, dynamic> json) {
    final id = json['linkId']?.toString();
    if (id == null || id.isEmpty) return null;
    return LinkedDevice(
      linkId: id,
      linkedAt: DateTime.tryParse(json['linkedAt']?.toString() ?? ''),
    );
  }
}

/// 보호자 화면이 보여줄 연결 상태.
///
/// 휴대폰은 **여러 대** 붙을 수 있다 — 태블릿과 휴대폰을 함께 쓰는 경우가 있다.
class LinkStatus {
  const LinkStatus({required this.devices, this.pendingExpiresAt});

  final List<LinkedDevice> devices;

  /// 발급했고 아직 아무도 쓰지 않은 암호의 만료 시각.
  final DateTime? pendingExpiresAt;

  bool get hasDevice => devices.isNotEmpty;

  static const empty = LinkStatus(devices: []);

  static LinkStatus fromJson(Map<String, dynamic> json) {
    final raw = json['devices'];
    return LinkStatus(
      // 서버가 형식을 바꿔도 화면이 죽지 않게 한 겹 막는다.
      devices: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(LinkedDevice.fromJson)
              .whereType<LinkedDevice>()
              .toList()
          : const [],
      pendingExpiresAt:
          DateTime.tryParse(json['pendingExpiresAt']?.toString() ?? ''),
    );
  }
}

/// 발급 결과. 원문 암호는 이 응답에만 있고 다시 물어볼 수 없다.
class IssuedLinkCode {
  const IssuedLinkCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  Duration remaining() {
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isExpired => remaining() == Duration.zero;
}
