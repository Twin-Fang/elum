import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../application/push_permission_prompt.dart';
import '../../data/notification_permission_gate.dart';

/// 기기 알림이 꺼져 있을 때만 보이는 안내 줄 + 기기 설정 열기 버튼
/// 설정 앱에서 돌아오면(resume) 권한을 다시 확인해 줄을 걷음
class DeviceNotificationPermissionBanner extends ConsumerStatefulWidget {
  const DeviceNotificationPermissionBanner({super.key});

  @override
  ConsumerState<DeviceNotificationPermissionBanner> createState() =>
      _DeviceNotificationPermissionBannerState();
}

class _DeviceNotificationPermissionBannerState
    extends ConsumerState<DeviceNotificationPermissionBanner>
    with WidgetsBindingObserver {
  static const _padding = 16.0;
  static const _textToButtonGap = 12.0;
  static const _radius = 16.0;

  /// 확인 전에는 숨김 (켜져 있는 기기에서 줄이 깜빡이지 않게)
  bool _isPermissionOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final isGranted = await ref.read(notificationPermissionGateProvider).isGranted();
      if (mounted) setState(() => _isPermissionOff = !isGranted);
    } catch (e, st) {
      // 확인 실패 시 줄을 띄우지 않음 (부가 안내)
      AppLogger.error('notification', e, st, {'step': 'checkPermission'});
    }
  }

  /// 버튼: 아직 한 번도 안 물은 기기면 시스템 권한 창, 이미 거부했으면 기기 설정
  Future<void> _requestOrOpenDeviceSettings() async {
    try {
      final isRequested = await ref
          .read(pushPermissionPromptProvider)
          .requestIfNeverAsked();
      if (isRequested) {
        await _checkPermission();
        return;
      }
    } catch (e, st) {
      AppLogger.error('notification', e, st, {'step': 'requestPermission'});
    }
    await _openDeviceSettings();
  }

  Future<void> _openDeviceSettings() async {
    try {
      await ref.read(notificationPermissionGateProvider).openDeviceSettings();
    } catch (e, st) {
      AppLogger.error('notification', e, st, {'step': 'openDeviceSettings'});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionOff) return const SizedBox.shrink();
    final colors = context.colors;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(_padding.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.notificationPermissionOff,
            style: context.typo.bodySmall.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: _textToButtonGap.h),
          ElumButton(
            label: l10n.notificationOpenDeviceSettings,
            onPressed: _requestOrOpenDeviceSettings,
          ),
        ],
      ),
    );
  }
}
