import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../data/member_repository.dart';
import 'member_providers.dart';

/// 서버가 형식·금지어·중복·7일 제한으로 거절한 실패인가 (시트에 사유를 두고 고쳐 쓰게 함)
///
/// 그 외(네트워크·서버 오류)는 실패 팝업으로 알림
bool isGuardianNicknameRejection(AppFailure failure) =>
    switch (failure.server?.code) {
      ServerErrorCode.nicknameInvalidFormat ||
      ServerErrorCode.nicknameNotAllowed ||
      ServerErrorCode.nicknameDuplicated ||
      ServerErrorCode.nicknameChangeTooSoon => true,
      _ => false,
    };

/// 보호자 닉네임 바꾸기: 저장 > 응답 회원 정보로 화면 갱신
///
/// 응답이 `/api/member/me` 와 같은 모양이라 다시 받지 않고 그대로 넣음
class GuardianNicknameEditor {
  GuardianNicknameEditor(this._ref);

  final Ref _ref;

  /// null 이면 저장 완료
  Future<AppFailure?> change(String nickname) async {
    final attempt = await _ref
        .read(memberRepositoryProvider)
        .updateGuardianNickname(nickname.trim());
    final member = attempt.value;
    if (member == null) return attempt.failure;
    _ref.read(memberPrefetchProvider).put(member);
    _ref.invalidate(memberProvider);
    return null;
  }
}

final guardianNicknameEditorProvider = Provider<GuardianNicknameEditor>(
  GuardianNicknameEditor.new,
);
