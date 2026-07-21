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

  /// 저장을 확정할 수 있는 상태 — 재입력 단계에서 4자리가 첫 입력과 일치할 때만.
  /// 불일치는 자동 리셋되지만, post-frame 사이 순간에 버튼이 열리지 않도록 값까지 본다.
  bool get _canConfirm =>
      _isConfirmStep &&
      _current.length == OnboardingProfile.pinLength &&
      _current == _firstEntry;

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
    } else {
      setState(() {});
    }

    // 4자리를 채우면 자동으로 다음으로 넘긴다 (이슈 #101).
    // 1단계는 재입력 단계로 자동 전환, 2단계는 자동 검증한다.
    // 단, 2단계 일치 시엔 자동 저장하지 않고 CTA만 활성화해 확정할 틈을 남긴다.
    if (_current.length == OnboardingProfile.pinLength) {
      if (!_isConfirmStep) {
        _advanceToConfirm();
      } else if (_current != _firstEntry) {
        // 일치 케이스는 자동 전환하지 않는다 — 여기선 불일치만 처리한다
        _resetOnMismatch();
      }
    }
  }

  /// 1단계 완료 → 재입력 단계로 자동 전환.
  /// clear()가 _onChanged를 재진입시키므로 프레임 이후로 미룬다.
  void _advanceToConfirm() {
    final entered = _current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _firstEntry = entered);
      _clearInput();
    });
  }

  /// 재입력 불일치 → 1단계로 되돌린다. 경고색·에러 아이콘은 쓰지 않는다.
  void _resetOnMismatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _firstEntry = null);
      _clearInput();
      setState(() => _errorMessage = '암호가 서로 달라요. 다시 만들어볼까요?');
    });
  }

  /// 최종 확정 — 2단계 일치 상태에서 CTA를 눌렀을 때만 호출된다.
  void _onComplete() {
    ref.read(onboardingProvider.notifier).setPin(_current);
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
      // 1단계·재입력 전환은 4자리 도달 시 자동으로 일어나므로, 이 버튼은
      // 재입력이 일치했을 때 저장을 최종 확정하는 용도로만 활성화된다.
      bottomButton: ElumButton(
        label: '맞춤 설정하기',
        onPressed: _canConfirm ? _onComplete : null,
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
