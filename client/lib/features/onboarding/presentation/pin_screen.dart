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
  String? _errorMessage;

  /// OS 키패드와 연결되는 실제 입력값.
  /// 자체 키패드를 두면 iOS·Android 각각의 입력 관습(햅틱·접근성·외부 키보드)을
  /// 다시 구현해야 한다. 시스템 키패드를 쓰고 화면에는 점만 그린다.
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String get _current => _controller.text;

  bool get _isConfirmStep => _firstEntry != null;

  @override
  void initState() {
    super.initState();
    // 화면에 들어오면 바로 키패드가 올라오게 한다
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    // 입력이 생기면 이전 안내 문구를 지운다
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
      return;
    }
    setState(() {});
  }

  // 4자리를 채워도 자동으로 넘어가지 않는다.
  // Figma가 모든 PIN 프레임에 CTA를 두고 있고, 자동 전환은 오타를 고칠 틈을 주지 않는다.

  void _onComplete() {
    final entered = _current;

    if (!_isConfirmStep) {
      // 1단계 완료 → 재입력 받기
      setState(() => _firstEntry = entered);
      _clearInput();
      return;
    }

    if (entered != _firstEntry) {
      // 불일치 — 처음부터 다시. 경고색·에러 아이콘은 쓰지 않는다.
      setState(() => _firstEntry = null);
      _clearInput();
      setState(() => _errorMessage = '암호가 서로 달라요. 다시 만들어볼까요?');
      return;
    }

    ref.read(onboardingProvider.notifier).setPin(entered);
    context.push(Routes.onboardingDone);
  }

  /// 입력을 비우고 키패드는 계속 올라와 있게 둔다
  void _clearInput() {
    _controller.clear();
    _focusNode.requestFocus();
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
          // 점을 누르면 키패드가 다시 올라온다 (내려버렸을 때의 탈출구)
          GestureDetector(
            onTap: _focusNode.requestFocus,
            behavior: HitTestBehavior.opaque,
            child: PinDots(
              length: OnboardingProfile.pinLength,
              filled: _current.length,
            ),
          ),
          PinInputField(
            controller: _controller,
            focusNode: _focusNode,
            maxLength: OnboardingProfile.pinLength,
          ),
        ],
      ),
    );
  }
}
