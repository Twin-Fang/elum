import 'package:flutter/foundation.dart';

import '../../../core/l10n/current_l10n.dart';
import '../../onboarding/domain/image_style.dart';

/// 연결된 이룸이 한 명 — 서버 `ProfileSummaryResponse`에 대응한다.
///
/// 출처: server/.../member/application/dto/response/ProfileSummaryResponse.java
///
/// 여러 이룸이를 돌보는 보호자가 이룸이를 고를 때 쓴다. [id] 가 `X-Profile-Id` 헤더 값이다.
@immutable
class ProfileSummary {
  const ProfileSummary({
    required this.id,
    this.nickname,
    this.character,
    this.imageStyle = ImageStyle.cartoon,
  });

  final String id;

  /// 이룸이 호칭. 온보딩 전이면 null.
  final String? nickname;

  /// 서버 `CharacterType` 값(`LULU`/`POPO`). 모르는 값이어도 그대로 담아 둔다 —
  /// 해석은 쓰는 쪽이 `CardCharacter.fromApiValue` 로 한다.
  final String? character;

  final ImageStyle imageStyle;

  /// 목록에 적을 이름. 비어 있으면 `이룸이`다 (이름을 모를 때 쓰는 말).
  String get displayName {
    final name = nickname?.trim();
    return (name == null || name.isEmpty) ? appL10n.commonElumiName : name;
  }

  /// 서버 응답 한 항목. **id 가 없으면 null** — 어느 이룸이인지 모르면 고를 수 없다.
  /// 모양이 달라도 던지지 않는다.
  static ProfileSummary? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final nickname = json['nickname']?.toString();
    final character = json['character']?.toString();
    return ProfileSummary(
      id: id,
      nickname: (nickname == null || nickname.isEmpty) ? null : nickname,
      character: (character == null || character.isEmpty) ? null : character,
      imageStyle: ImageStyle.fromApiValue(
        json['imageStyle'] is String ? json['imageStyle'] as String : null,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileSummary &&
      other.id == id &&
      other.nickname == nickname &&
      other.character == character &&
      other.imageStyle == imageStyle;

  @override
  int get hashCode => Object.hash(id, nickname, character, imageStyle);
}
