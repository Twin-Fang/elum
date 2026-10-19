import 'package:flutter/foundation.dart';

import '../../auth/domain/oauth_provider.dart';

/// 보호자 계정 표시 정보 — 서버 `MemberResponse.account` + `createdAt` (#849)
///
/// 원본 이메일은 오지 않는다. 필드가 없거나 모양이 달라도 예외 없이 null 로 둔다.
@immutable
class GuardianAccount {
  const GuardianAccount({
    this.nickname,
    this.signInProvider,
    this.maskedEmail,
    this.joinedAt,
  });

  /// 보호자 닉네임 (가입 시 서버 자동 생성). 기존 계정은 서버가 채우기 전까지 null
  final String? nickname;

  /// 가입한 소셜 제공자. 아이디·비밀번호 가입이거나 모르는 값이면 null
  final OAuthProvider? signInProvider;

  /// 가린 이메일 (예: ab***@kakao.com). 없거나 애플 숨김 주소면 null > "이메일 비공개"
  final String? maskedEmail;

  /// 가입 일시 (서버 KST)
  final DateTime? joinedAt;

  /// `account` 객체 + 최상위 `createdAt` > 표시 정보
  factory GuardianAccount.fromMemberJson(Map<String, dynamic> json) {
    final account = json['account'];
    final accountJson = account is Map ? account : const {};
    return GuardianAccount(
      nickname: _nonEmptyString(accountJson['nickname']),
      signInProvider: _toSignInProvider(accountJson['signInProvider']),
      maskedEmail: _nonEmptyString(accountJson['maskedEmail']),
      joinedAt: switch (json['createdAt']) {
        final String raw => DateTime.tryParse(raw),
        _ => null,
      },
    );
  }

  static String? _nonEmptyString(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 서버 enum(KAKAO 등) > 앱 enum
  static OAuthProvider? _toSignInProvider(Object? raw) {
    if (raw is! String) return null;
    final lowered = raw.toLowerCase();
    for (final provider in OAuthProvider.values) {
      if (provider.name == lowered) return provider;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is GuardianAccount &&
      other.nickname == nickname &&
      other.signInProvider == signInProvider &&
      other.maskedEmail == maskedEmail &&
      other.joinedAt == joinedAt;

  @override
  int get hashCode => Object.hash(nickname, signInProvider, maskedEmail, joinedAt);
}
