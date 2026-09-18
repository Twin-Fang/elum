import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_shake.dart';
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

  /// 재입력이 틀린 횟수. 값이 바뀔 때마다 점이 한 번 흔들린다.
  int _mismatchCount = 0;

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
    // 다시 입력하기 시작하면 이전 안내 문구를 지운다.
    // _clearInput()이 만드는 빈 값에는 반응하지 않는다 — 방금 띄운 안내가
    // 곧바로 사라져 무엇이 잘못됐는지 읽을 틈이 없어진다.
    if (_errorMessage != null && _current.isNotEmpty) {
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
        _resetOnMismatch();
      } else {
        _revealConfirmCta();
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

  /// 재입력 일치 → 키패드를 내려 CTA를 드러낸다.
  ///
  /// 저장은 여기서 하지 않는다(확정할 틈을 남긴다). 다만 키패드를 띄워두면
  /// 화면 하단의 `시작하기`가 그 뒤에 숨어, 4자리를 두 번 다 넣고도
  /// 다음에 뭘 해야 할지 알 수 없다 — 실기기 테스트에서 실제로 막혔다.
  /// 점을 누르면 키패드가 다시 올라오므로 되돌릴 길은 남아 있다.
  void _revealConfirmCta() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.unfocus();
    });
  }

  /// 재입력 불일치 → 재입력만 비운다. 경고색·에러 아이콘은 쓰지 않는다.
  ///
  /// 사용자가 정한 암호(1단계 입력)는 그대로 둔다. 확인 한 번 잘못 눌렀다고
  /// 암호까지 없애면 네 자리를 두 번 더 쳐야 한다. 처음부터 다시 만들고 싶으면
  /// 뒤로가기로 돌아갈 수 있다.
  ///
  /// 색 대신 [AppShake]로 알린다 — 이 서비스는 실패에 경고색을 쓰지 않는다.
  void _resetOnMismatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _clearInput();
      setState(() {
        _errorMessage = '암호가 달라요. 다시 넣어주세요';
        _mismatchCount++;
      });
    });
  }

  /// 최종 확정 — 2단계 일치 상태에서 CTA를 눌렀을 때만 호출된다.
  void _onComplete() async {
    ref.read(onboardingProvider.notifier).setPin(_current);
    await ref.read(onboardingProvider.notifier).complete();
    if (mounted) {
      context.go(Routes.guardian);
    }
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
      // 시안(238:2924)에는 **입력 중에 버튼이 아예 없다** (이슈 #231).
      //
      // 전에는 비활성 버튼을 깔아 뒀는데, 그러면 네 자리를 넣고도 "이걸 눌러야
      // 하나" 하고 멈춘다. 눌리지 않는 버튼은 알려주는 게 없다. 두 번 맞춰
      // 넣으면 그때 나타나므로, **나타나는 것 자체가 다 됐다는 신호**가 된다.
      bottomButton: _canConfirm
          ? ElumButton(label: '시작하기', onPressed: _onComplete)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            // Figma 238:2767 — 재입력 단계의 제목
            // 시안 문구 그대로 쓴다 (238:2767 · 238:2924).
            // `보호자모드`는 #196에서 `보호자 화면`으로 한 번 바꿨던 말인데,
            // **시안을 따르기로 합의했다** (이슈 #228 — 기기만 휴대폰으로 바꾸고
            // 코드·모드는 시안대로). 자세한 근거는 루트 CLAUDE.md 용어 규칙.
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
            child: AppShake(
              trigger: _mismatchCount,
              child: PinDots(
                length: OnboardingProfile.pinLength,
                filled: _current.length,
              ),
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
