import '../../member/data/member_repository.dart';

/// 두 홈이 같은 이룸이를 부르도록 선택한 프로필의 이름을 함께 사용한다.
String resolveProfileDisplayName(
  Member? member,
  String? selectedId,
  String localName,
) {
  String? name(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  if (selectedId != null && selectedId.isNotEmpty) {
    for (final profile in member?.profiles ?? const []) {
      if (profile.id == selectedId) {
        return name(profile.nickname) ?? localName;
      }
    }
    // 프로필 전환 직후 옛 응답의 다른 이룸이 이름으로 되돌아가지 않게 한다.
    if (member?.profiles.isNotEmpty ?? false) return localName;
  }
  // 목록을 주지 않는 구버전 응답과 이룸이 휴대폰은 기존 회원 이름을 사용한다.
  return name(member?.nickname) ?? localName;
}
