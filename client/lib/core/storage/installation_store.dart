import 'local_storage.dart';
import 'package:flutter/services.dart';

/// 설치 표식 오류는 신규 설치와 구분하여 인증 화면 진입을 막는다.
class InstallationException implements Exception {
  InstallationException(this.cause);
  final Object cause;
  @override
  String toString() => 'E-INSTALL';
}

class InstallationStore {
  const InstallationStore({
    MethodChannel channel = const MethodChannel('elum/installation'),
  }) : _channel = channel;
  final MethodChannel _channel;

  Future<String> load() async {
    try {
      final id = await _channel.invokeMethod<String>('getInstallationId');
      if (id == null || id.trim().isEmpty) {
        throw const FormatException('empty installation id');
      }
      return id;
    } catch (error) {
      throw InstallationException(error);
    }
  }
}

/// 백업 제외 표식 도입 이전 설치는 로컬 앱 상태가 남아 있을 때만 이전한다.
///
/// 앱을 지우면 로컬 상태가 함께 지워지고 업데이트면 남으므로, 재설치와 업데이트는 이것만으로
/// 가린다. 프로필 ID·이름까지 요구하면 그 값이 비어 있던 기존 휴대폰(연결 직후 조회에 실패한
/// 이룸이 휴대폰 등)이 업데이트만으로 로그아웃된다.
bool canMigrateLegacyInstallation(LocalStorage storage) =>
    storage.isOnboardingCompleted ||
    storage.isElumiDevice ||
    storage.selectedRole != null;
