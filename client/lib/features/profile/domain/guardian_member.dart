import 'package:flutter/foundation.dart';

import '../../../core/l10n/current_l10n.dart';

/// 보호자 구분 — 서버 `GuardianKind`. **표시용이다. 권한 차이는 없다** (명세 2장).
enum GuardianKind {
  guardian('GUARDIAN'),
  caregiver('CAREGIVER');

  const GuardianKind(this.apiValue);

  final String apiValue;

  /// 표시용 구분 이름 — 앱 언어의 문구다. 서버로 가는 값은 [apiValue] 뿐이다.
  String get label => switch (this) {
    GuardianKind.guardian => appL10n.guardianKindGuardian,
    GuardianKind.caregiver => appL10n.guardianKindCaregiver,
  };

  /// 모르는 값이면 [guardian] 이다 — 서버가 새 구분을 먼저 배포해도 목록이 죽지 않는다.
  static GuardianKind fromApiValue(String? value) {
    for (final k in GuardianKind.values) {
      if (k.apiValue == value) return k;
    }
    return GuardianKind.guardian;
  }
}

/// 이룸이를 함께 돌보는 사람 한 명 — 서버 `GuardianResponse`에 대응한다 (#361).
///
/// 출처: server/.../member/application/dto/response/GuardianResponse.java
///
/// 계정 ID·아이디는 내려오지 않는다 (소셜 가입자의 아이디는 내부 식별자라 다른 보호자에게
/// 보일 수 없다). 보호자를 부르는 이름은 이 이룸이 안에서 본인이 정한 [displayName] 뿐이다.
@immutable
class Guardian {
  const Guardian({
    required this.id,
    required this.me,
    this.displayName,
    this.kind = GuardianKind.guardian,
    this.joinedAt,
  });

  /// 이 이룸이와의 **관계** ID. 계정 ID 가 아니다.
  final String id;

  /// 나인가. 나가기·이름 고치기는 이 항목에만 보인다.
  final bool me;

  /// 이 이룸이 안에서 불리는 이름. 비면 null — 앱이 `보호자`로 부른다.
  final String? displayName;

  final GuardianKind kind;
  final DateTime? joinedAt;

  /// 목록에 적을 이름.
  String get label {
    final name = displayName?.trim();
    return (name == null || name.isEmpty) ? appL10n.commonGuardianName : name;
  }

  /// 서버 응답 한 항목. id 가 없으면 null. 모양이 달라도 던지지 않는다.
  static Guardian? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final name = json['displayName']?.toString();
    return Guardian(
      id: id,
      me: json['me'] == true,
      displayName: (name == null || name.isEmpty) ? null : name,
      kind: GuardianKind.fromApiValue(json['kind']?.toString()),
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? ''),
    );
  }
}
