import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../application/onboarding_notifier.dart';
import '../domain/onboarding_profile.dart';
import 'widgets/pin_keypad.dart';

/// Figma `온보딩_비밀번호` — 보호자 모드 전환용 PIN을 만든다.
///
/// 입력 → 재입력 확인 2단계. 별도 라우트가 아니라 한 화면의 상태로 다룬다.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  /// 1단계에서 입력한 PIN. null이면 아직 1단계다.
  String? _firstEntry;
  String _current = '';
  String? _errorMessage;

  bool get _isConfirmStep => _firstEntry != null;

  void _onDigit(String digit) {
    if (_current.length >= OnboardingProfile.pinLength) return;

    setState(() {
      _current += digit;
      _errorMessage = null;
    });
  }

  // 4자리를 채워도 자동으로 넘어가지 않는다.
  // Figma가 모든 PIN 프레임에 CTA를 두고 있고, 자동 전환은 오타를 고칠 틈을 주지 않는다.

  void _onBackspace() {
    if (_current.isEmpty) return;
    setState(() => _current = _current.substring(0, _current.length - 1));
  }

  void _onComplete() {
    if (!_isConfirmStep) {
      // 1단계 완료 → 재입력 받기
      setState(() {
        _firstEntry = _current;
        _current = '';
      });
      return;
    }

    if (_current != _firstEntry) {
      // 불일치 — 처음부터 다시. 경고색·에러 아이콘은 쓰지 않는다.
      setState(() {
        _firstEntry = null;
        _current = '';
        _errorMessage = '암호가 서로 달라요. 다시 만들어볼까요?';
      });
      return;
    }

    ref.read(onboardingProvider.notifier).setPin(_current);
    context.push(Routes.onboardingDone);
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return ElumScaffold(
      onBack: () => context.pop(),
      // Figma 238:1909의 CTA는 "다음"이 아니라 "맞춤 설정하기"다.
      // 4자리를 채우면 자동으로 다음 단계로 넘어가므로 이 버튼은 확인용이다.
      bottomButton: ElumButton(
        label: '맞춤 설정하기',
        onPressed: _current.length == OnboardingProfile.pinLength
            ? _onComplete
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            // Figma 238:2767 — 재입력 단계의 제목
            title: _isConfirmStep
                ? '암호를 한번 더\n입력해주세요'
                : '보호자님만 아는\n비밀암호를 만들어주세요',
            description: _errorMessage ?? '보호자모드로 변경할 때 사용하는 암호예요',
          ),
          SizedBox(height: space.xl),
          PinDots(
            length: OnboardingProfile.pinLength,
            filled: _current.length,
          ),
          const Spacer(),
          PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
        ],
      ),
    );
  }
}

/// Figma `온보딩_비밀번호_완료` — 설정을 저장하고 보호자 홈으로 보낸다.
class OnboardingDoneScreen extends ConsumerWidget {
  const OnboardingDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);

    return ElumScaffold(
      bottomButton: ElumButton(
        label: '맞춤 설정하기',
        onPressed: () async {
          await ref.read(onboardingProvider.notifier).complete();
          if (context.mounted) context.go(Routes.guardian);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            title: '${profile.displayName}를 위한\n준비가 끝났어요',
            // 진단명 없는 개인화 — 발표에서 강조하는 지점
            description: '선택하신 도움 목표에 맞춰 카드를 만들어드릴게요',
          ),
        ],
      ),
    );
  }
}
