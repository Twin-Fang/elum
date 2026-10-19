import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/push_permission_sheet.dart';
import '../data/push_messaging_client.dart';
import '../domain/push_permission_status.dart';
import 'push_token_registrar.dart';

final pushPermissionPromptProvider = Provider<PushPermissionPrompt>(
  PushPermissionPrompt.new,
);

/// 알림 권한 요청 한 곳: 안내 시트(첫 일과를 보낸 뒤 한 번) + 설정 화면의 직접 요청
/// 요청은 모두 [PushMessagingClient] 한 경로 (iOS APNs 등록이 함께 일어남)
class PushPermissionPrompt {
  PushPermissionPrompt(this._ref);

  final Ref _ref;

  /// 안내 시트가 떠 있는 동안 두 번째 호출 무시
  bool _isAsking = false;

  PushMessagingClient get _client => _ref.read(pushMessagingClientProvider);

  LocalStorage get _storage => _ref.read(localStorageProvider);

  /// 첫 일과를 보낸 직후: 한 번도 안 물었으면 안내 시트 > 시스템 권한 창 > 토큰 등록
  /// 이미 물었거나, 이룸이 기기이거나, 이미 허용·거부 상태면 시트 없이 정리만
  Future<void> maybeAsk(BuildContext context) async {
    if (_isAsking ||
        _storage.hasAskedPushPermission ||
        _storage.isElumiDevice) {
      return;
    }
    _isAsking = true;
    try {
      final status = await _readStatus();
      if (status == null) return; // 확인 실패: 플래그 없이 다음 기회에
      if (status != PushPermissionStatus.notDetermined) {
        // 허용이면 등록, 이미 거부했으면 시스템 창이 다시 뜨지 않으므로 안내 시트도 생략
        await _storage.setHasAskedPushPermission(true);
        if (status.isGranted) {
          await _ref.read(pushTokenRegistrarProvider).syncRegistration();
        }
        return;
      }
      // 화면 전환(홈 이동)이 끝난 뒤 띄움
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      final isAllowed = await showPushPermissionSheet(context);
      await _storage.setHasAskedPushPermission(true);
      if (isAllowed != true) return; // 나중에·닫기: 플래그만
      final isGranted = await _requestAndRegister();
      if (isGranted == false && context.mounted) {
        // 본인이 거부한 것이라 오류 팝업이 아니라 안내 토스트
        AppLogger.info('[push] permission denied by user');
        showElumToast(context, context.l10n.pushPermissionDenied);
      }
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'maybeAsk'});
    } finally {
      _isAsking = false;
    }
  }

  /// 알림 설정 화면의 안내 줄 버튼: 아직 한 번도 안 물은 기기면 시스템 창을 띄움
  /// 시스템 창을 띄웠으면 true, 이미 물었으면(거부 상태) false (호출부가 기기 설정을 엶)
  Future<bool> requestIfNeverAsked() async {
    final status = await _readStatus();
    if (status != PushPermissionStatus.notDetermined) return false;
    await _storage.setHasAskedPushPermission(true);
    await _requestAndRegister();
    return true;
  }

  /// 시스템 권한 창 > 허용이면 토큰 등록. 요청 자체가 실패하면 null
  Future<bool?> _requestAndRegister() async {
    try {
      final isGranted = await _client.requestPermission();
      if (isGranted) {
        await _ref.read(pushTokenRegistrarProvider).syncRegistration();
      }
      return isGranted;
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'requestPermission'});
      return null;
    }
  }

  Future<PushPermissionStatus?> _readStatus() async {
    try {
      return await _client.permissionStatus();
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'permissionStatus'});
      return null;
    }
  }
}
