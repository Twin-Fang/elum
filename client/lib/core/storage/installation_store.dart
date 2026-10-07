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

/// 백업 제외 표식 도입 이전 설치는 일관된 로컬 자료가 남았을 때만 이전한다.
bool canMigrateLegacyInstallation(LocalStorage storage) {
  final hasProfile =
      storage.selectedProfileId?.isNotEmpty == true &&
      storage.nickname?.trim().isNotEmpty == true;
  return storage.isOnboardingCompleted &&
      hasProfile &&
      (storage.isElumiDevice || storage.selectedRole == 'guardian');
}
