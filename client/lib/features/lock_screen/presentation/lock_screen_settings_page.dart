import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_info_card.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/lock_screen_providers.dart';
import 'lock_screen_permission_steps.dart';
import 'widgets/lock_screen_enabled_panel.dart';
import 'widgets/lock_screen_interval_picker.dart';
import 'widgets/lock_screen_permission_step_card.dart';
import 'widgets/lock_screen_setup_progress.dart';

/// 잠금화면 카드 설정 (기본 꺼짐, 사용자가 켬): 소개 카드 > (켜짐) 상태·간격·미리 보기·끄기 / (꺼짐) 간격 > 진행 막대 > 권한 단계 카드 > 준비 끝
/// 필수 3개가 모두 켜지면 바로 켜기. 설정 앱에서 돌아오면 권한을 다시 읽어 자동 체크
/// 일부 거부면 그 단계에서 멈추고 이유·설정 열기를 보임 (기능은 꺼진 채)
class LockScreenSettingsPage extends ConsumerStatefulWidget {
  const LockScreenSettingsPage({super.key});

  @override
  ConsumerState<LockScreenSettingsPage> createState() =>
      _LockScreenSettingsPageState();
}

class _LockScreenSettingsPageState
    extends ConsumerState<LockScreenSettingsPage> {
  late final AppLifecycleListener _lifecycleListener;

  LockScreenPermissionStatus _status = LockScreenPermissionStatus.none;

  /// 설정 화면을 열고 돌아오기를 기다리는 단계
  LockScreenPermissionStep? _openedStep;

  /// 삼성 절전 예외: 결과를 읽을 수 없어 "추가했어요"·건너뛰기로만 끝
  bool _isSamsungStepFinished = false;
  bool _isSamsungStepAwaitingConfirmation = false;

  int _selectedIntervalMinutes = lockScreenDefaultIntervalMinutes;
  bool _isEnabling = false;

  /// 이 화면에서 켜기를 마쳤나 (준비 끝 표시)
  bool _hasEnabledHere = false;

  // 필수 권한이 다 있는데 네이티브가 켜기를 거부했을 때 코드
  static const _enableFailedErrorCode = 'E-LOCK-ENABLE';

  LockScreenBridge get _bridge => ref.read(lockScreenBridgeProvider);

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _onResume);
    unawaited(_reloadStatus(shouldAutoEnable: false));
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  List<LockScreenPermissionStep> get _steps =>
      LockScreenPermissionStep.stepsFor(_status);

  bool _isStepDone(LockScreenPermissionStep step) =>
      step.isDoneIn(_status, isSamsungStepFinished: _isSamsungStepFinished);

  /// 지금 할 단계: 순서대로 첫 미완료 (모두 끝났으면 null)
  LockScreenPermissionStep? get _currentStep =>
      _steps.where((step) => !_isStepDone(step)).firstOrNull;

  /// 설정에서 돌아옴: 삼성 단계면 확인 안내 > 권한 다시 읽기 > 필수 다 켜졌으면 켜기
  Future<void> _onResume() async {
    final openedStep = _openedStep;
    _openedStep = null;
    if (openedStep == LockScreenPermissionStep.samsungPower) {
      setState(() => _isSamsungStepAwaitingConfirmation = true);
    }
    await _reloadStatus(shouldAutoEnable: openedStep != null);
  }

  Future<void> _reloadStatus({required bool shouldAutoEnable}) async {
    final status = await _bridge.getPermissionStatus();
    if (!mounted) return;
    setState(() => _status = status);
    final lockScreenState = await ref
        .read(lockScreenStateProvider.notifier)
        .refresh();
    if (!mounted) return;
    final isEnabled = lockScreenState.settings.isEnabled;
    if (!isEnabled) {
      _selectedIntervalMinutes = lockScreenState.settings.intervalMinutes;
    }
    if (shouldAutoEnable && status.hasRequiredPermissions && !isEnabled) {
      await _enable();
    }
  }

  Future<void> _enable() async {
    if (_isEnabling) return;
    setState(() => _isEnabling = true);
    final isEnabled = await ref
        .read(lockScreenStateProvider.notifier)
        .enable(selectedIntervalMinutes: _selectedIntervalMinutes);
    if (!mounted) return;
    setState(() {
      _isEnabling = false;
      _hasEnabledHere = isEnabled;
    });
    if (!isEnabled) {
      await showFailureMessage(
        context,
        sentence: context.l10n.lockScreenEnableFailed,
        code: _enableFailedErrorCode,
      );
    }
  }

  void _openSettings(LockScreenPermissionStep step) {
    _openedStep = step;
    unawaited(step.openSettings(_bridge));
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final mode = ref.watch(lockScreenDeviceModeProvider);
    final lockScreenState = ref.watch(lockScreenStateProvider).value;
    final isEnabled = lockScreenState?.settings.isEnabled ?? false;
    final isPermissionMissing = lockScreenState?.isPermissionMissing ?? false;
    final isFinished = _hasEnabledHere && isEnabled && _currentStep == null;
    return ElumScaffold(
      onBack: context.popOrHome,
      title: context.l10n.lockScreenSettingsTitle,
      backTop: ElumScaffold.settingsBackTop,
      horizontalPadding: 16,
      bottomButton: isFinished
          ? ElumButton(
              label: context.l10n.lockScreenSetupComplete,
              onPressed: context.popOrHome,
            )
          : null,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: space.lg.h),
            ElumInfoCard(
              layout: ElumInfoCardLayout.top,
              illustrationAsset: AppAssets.featureIconLockScreen,
              title: mode == LockScreenMode.elumi
                  ? context.l10n.lockScreenElumiIntroTitle
                  : context.l10n.lockScreenGuardianIntroTitle,
              body: context.l10n.lockScreenIntroNoAdsNote,
            ),
            SizedBox(height: space.lg.h),
            if (isEnabled && !isPermissionMissing && !isFinished)
              LockScreenEnabledPanel(settings: lockScreenState!.settings)
            else
              ..._setupSteps(context, isFinished: isFinished),
            SizedBox(height: space.lg.h),
          ],
        ),
      ),
    );
  }

  /// 꺼진 상태: 간격 > 진행 막대 > 단계 카드 > 준비 끝
  List<Widget> _setupSteps(BuildContext context, {required bool isFinished}) {
    final space = context.space;
    final steps = _steps;
    final currentStep = _currentStep;
    return [
      LockScreenIntervalPicker(
        selectedIntervalMinutes: _selectedIntervalMinutes,
        onSelected: (intervalMinutes) =>
            setState(() => _selectedIntervalMinutes = intervalMinutes),
      ),
      SizedBox(height: space.lg.h),
      LockScreenSetupProgress(
        doneCount: steps.where(_isStepDone).length,
        totalCount: steps.length,
      ),
      SizedBox(height: space.md.h),
      for (final step in steps) ...[
        LockScreenPermissionStepCard(
          title: step.title(context),
          reason: step.reason(context),
          isRequired: step.isRequired,
          isDone: _isStepDone(step),
          isCurrent: step == currentStep,
          onOpenSettings: () => _openSettings(step),
          onSkip: step.isRequired
              ? null
              : () => setState(() => _isSamsungStepFinished = true),
          pathHint: step == LockScreenPermissionStep.samsungPower
              ? context.l10n.lockScreenPermissionSamsungHint
              : null,
          onConfirmDone:
              step == LockScreenPermissionStep.samsungPower &&
                  _isSamsungStepAwaitingConfirmation
              ? () => setState(() => _isSamsungStepFinished = true)
              : null,
        ),
        SizedBox(height: space.xs.h),
      ],
      // 필수 다 켜졌는데 아직 안 켜졌으면(삼성 단계만 남음 등) 직접 켜기
      if (_status.hasRequiredPermissions && !_hasEnabledHere) ...[
        SizedBox(height: space.sm.h),
        ElumButton(
          label: context.l10n.lockScreenTurnOn,
          loading: _isEnabling,
          onPressed: _enable,
        ),
      ],
      if (isFinished) const LockScreenSetupDoneMessage(),
    ];
  }
}
