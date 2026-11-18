import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../guardian/application/home_next_step.dart';
import '../application/onboarding_exit_route.dart';
import 'widgets/device_usage_choice_card.dart';

/// 온보딩 마지막 단계 (#1473): 이룸이가 쓸 기기 고르기 2장 > `다음` · `나중에 정할게요`
/// 다른 기기 > 연결 코드 화면(온보딩 모드). 이 기기 > 홈 연결 권유 끔 + 이룸이 화면(예시 일과) + 돌아오는 법 안내. 나중에 > 보호자 홈
class LinkDeviceStepScreen extends ConsumerStatefulWidget {
  const LinkDeviceStepScreen({super.key});

  @override
  ConsumerState<LinkDeviceStepScreen> createState() => _LinkDeviceStepScreenState();
}

/// 이룸이가 쓸 기기 2가지
enum _ElumiDeviceChoice { otherDevice, thisDevice }

class _LinkDeviceStepScreenState extends ConsumerState<LinkDeviceStepScreen> {
  /// 헤더 > 첫 카드, 카드 사이 (역할 선택 화면과 같은 값)
  static const _headerToCardsSpacing = 52.0;
  static const _cardSpacing = 16.0;

  _ElumiDeviceChoice? _selectedChoice;

  /// 다음 자리로 옮기는 중 (두 번 누름 무시)
  bool _isLeaving = false;

  /// 다음: 고르기와 확정을 나눔 (잘못 눌러도 되돌릴 여지)
  Future<void> _submit() async {
    switch (_selectedChoice) {
      case _ElumiDeviceChoice.otherDevice:
        context.push(Routes.linkCodeFromOnboarding);
      case _ElumiDeviceChoice.thisDevice:
        await _startOnThisDevice();
      case null:
        return;
    }
  }

  /// 이 기기를 같이 씀: 홈 연결 권유 끔(#1435 와 같은 저장값) > 이룸이 화면 > 돌아오는 법 토스트
  Future<void> _startOnThisDevice() async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    // 저장 실패해도 dismiss 안에서 기록만 하고 넘어감
    await ref.read(isLinkDeviceSuggestionDismissedProvider.notifier).dismiss();
    if (!mounted) return;
    // 화면을 옮긴 뒤에는 이 context 가 없어 토스트 자리를 먼저 잡아 둠
    final messenger = ScaffoldMessenger.maybeOf(context);
    final returnHint = context.l10n.onboardingDeviceUsageReturnHint;
    context.go(Routes.child);
    showElumToastOn(messenger, returnHint);
  }

  /// 나중에: 보호자 홈 (go 로 온보딩 스택을 끝냄)
  Future<void> _later() async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    final nextRoute = await ref.read(onboardingExitRouteProvider).resolveAfterLinkStep();
    if (!mounted) return;
    context.go(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      // 비밀암호 화면이 go 로 끝나 돌아갈 곳이 없음 > 시스템 뒤로가기 = 나중에
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _later();
      },
      child: ElumScaffold(
        bottomButton: ElumButton(
          label: l10n.commonNext,
          onPressed: _selectedChoice != null && !_isLeaving ? _submit : null,
        ),
        belowButton: ElumSecondaryButton(label: l10n.onboardingDeviceUsageLater, onTap: _isLeaving ? null : _later),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElumHeader(title: l10n.onboardingDeviceUsageTitle, description: l10n.onboardingDeviceUsageDescription),
              SizedBox(height: _headerToCardsSpacing.h),
              _choiceCard(_ElumiDeviceChoice.otherDevice),
              SizedBox(height: _cardSpacing.h),
              _choiceCard(_ElumiDeviceChoice.thisDevice),
            ],
          ),
        ),
      ),
    );
  }

  /// 고르기 카드 (다른 기기는 이룸이 주황, 이 기기는 보호자 포인트색: 역할 선택 화면과 같은 색 뜻)
  Widget _choiceCard(_ElumiDeviceChoice choice) {
    final l10n = context.l10n;
    final colors = context.colors;
    final isOtherDevice = choice == _ElumiDeviceChoice.otherDevice;
    return AppPressable(
      onTap: _isLeaving ? null : () => setState(() => _selectedChoice = choice),
      child: DeviceUsageChoiceCard(
        highlightedWord: isOtherDevice ? l10n.onboardingDeviceUsageOtherWord : l10n.onboardingDeviceUsageThisWord,
        titleSuffix: isOtherDevice ? l10n.onboardingDeviceUsageOtherSuffix : l10n.onboardingDeviceUsageThisSuffix,
        description: isOtherDevice
            ? l10n.onboardingDeviceUsageOtherDescription
            : l10n.onboardingDeviceUsageThisDescription,
        highlightColor: isOtherDevice ? colors.roleElumi : colors.checkDone,
        isSelected: _selectedChoice == choice,
      ),
    );
  }
}
