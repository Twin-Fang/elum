import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../onboarding/domain/onboarding_profile.dart';
import '../../onboarding/presentation/widgets/pin_keypad.dart';
import '../../onboarding/application/onboarding_notifier.dart';

/// Figma `보호자_아이화면_전환`(309:2837).
///
/// **양방향으로 쓰인다.** Figma에 두 벌이 있는데 문구만 다르다. 화면을 둘로
/// 나누면 PIN 입력 로직이 복제되므로 목적지를 파라미터로 받는다.
///
/// PIN이 틀려도 **경고색·에러 아이콘을 쓰지 않는다.** 아동도 보는 화면이다.
class ModeSwitchScreen extends ConsumerStatefulWidget {
  const ModeSwitchScreen({super.key, required this.target});

  /// 어디로 갈 것인가. 문구와 이동 경로가 갈린다.
  final ModeSwitchTarget target;

  @override
  ConsumerState<ModeSwitchScreen> createState() => _ModeSwitchScreenState();
}

class _ModeSwitchScreenState extends ConsumerState<ModeSwitchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
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
    setState(() {});
    if (_controller.text.length == OnboardingProfile.pinLength) _verify();
  }

  Future<void> _verify() async {
    final saved = await ref.read(localStorageProvider).getPin();

    // PIN을 설정하지 않았으면(온보딩을 건너뛴 개발 상태) 그냥 통과시킨다.
    // 여기서 막으면 화면을 열어볼 방법이 없다.
    final isValid = saved == null || saved.isEmpty || saved == _controller.text;

    if (!mounted) return;

    if (isValid) {
      context.go(widget.target.route);
      return;
    }

    // 틀렸다 — 조용히 비우고 다시 받는다. 붉은 경고를 띄우지 않는다.
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return ElumScaffold(
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: space.xl),
          Text(
            '비밀암호를 입력하세요',
            // 온보딩 PIN 화면과 같은 크기다 (Figma 28/w800)
            style: context.typo.pinTitle
                .copyWith(color: context.colors.textPrimary),
          ),
          SizedBox(height: space.sm),
          Text(
            widget.target.description,
            style: context.typo.body
                .copyWith(color: context.colors.textSecondary),
          ),
          SizedBox(height: space.xl * 2),
          PinDots(
            length: OnboardingProfile.pinLength,
            filled: _controller.text.length,
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

/// 전환 목적지. 문구와 경로가 함께 붙어 있어야 어긋나지 않는다.
enum ModeSwitchTarget {
  child('암호를 입력하면 아이 화면으로 전환돼요', Routes.child),
  guardian('암호를 입력하면 보호자 화면으로 전환돼요', Routes.guardian);

  const ModeSwitchTarget(this.description, this.route);

  final String description;
  final String route;

  /// 쿼리 파라미터에서 복원한다. 모르는 값이면 아이 화면으로 본다.
  static ModeSwitchTarget fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return child;
  }
}
