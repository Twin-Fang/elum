import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_shake.dart';
import '../../../core/widgets/elum_header.dart';
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

  /// 틀린 횟수. [AppShake]의 trigger로 쓴다 — 값이 바뀔 때마다 흔들린다.
  int _mismatchCount = 0;

  /// 실패 안내. null이면 원래 설명을 보여준다.
  String? _errorMessage;

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
    setState(() {
      // 다시 누르기 시작하면 실패 안내를 거둔다 — 남겨두면 지금 틀린 것처럼 보인다.
      if (_errorMessage != null && _controller.text.isNotEmpty) {
        _errorMessage = null;
      }
    });
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

    // 틀렸다 — 점을 흔들고 문구로 알린다 (#180).
    // 종전에는 입력만 조용히 비웠다. 틀린 것인지, 입력이 안 먹은 것인지, 화면이 멈춘
    // 것인지 구분할 수 없어 같은 암호를 다시 누르게 됐다.
    //
    // 색 대신 [AppShake]로 알린다 — 아동도 보는 화면이라 경고색을 쓰지 않는다.
    // 온보딩 PIN 화면(pin_screen)과 같은 방식이다.
    //
    // 비우는 것은 다음 프레임에 한다. 지금은 _onChanged가 도는 중이라
    // 여기서 clear하면 그 리스너가 곧바로 _errorMessage를 지워버린다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.clear();
      _focusNode.requestFocus();
      setState(() {
        _errorMessage = '암호가 달라요. 다시 넣어주세요';
        _mismatchCount++;
      });
    });
  }

  /// 설명 하단(193) → 점(299). 시안 `309:2837` 실측.
  ///
  /// **점은 비밀번호 화면과 같은 y=299에 있다.** 다만 이 화면은 제목이 한 줄이라
  /// 설명이 위(177)에 서고, 그래서 남는 간격이 106으로 더 크다. 거기 72를 쓰면
  /// 점이 34 떠 오른다.
  static const _descriptionToDots = 106.0;

  @override
  Widget build(BuildContext context) {
    return ElumScaffold(
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 제목·설명을 손으로 쌓지 않는다 — 뼈대가 쓰는 간격과 어긋난다.
          // 실제로 `space.xl`(32)을 쓰다 제목이 20 내려가 있었다 (#297).
          ElumHeader(
            // 시안 `309:2837` 문구 그대로
            title: '비밀암호를 입력하세요',
            // 틀렸을 때는 실패 안내로 바뀐다. 색은 그대로 둔다 (#180).
            description: _errorMessage ?? widget.target.description,
          ),
          SizedBox(height: _descriptionToDots.h),
          // 점을 누르면 키패드가 다시 올라온다 (내려버렸을 때의 탈출구)
          GestureDetector(
            onTap: _focusNode.requestFocus,
            behavior: HitTestBehavior.opaque,
            child: AppShake(
              trigger: _mismatchCount,
              child: PinDots(
                length: OnboardingProfile.pinLength,
                filled: _controller.text.length,
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

/// 전환 목적지. 문구와 경로가 함께 붙어 있어야 어긋나지 않는다.
enum ModeSwitchTarget {
  // 시안(`309:2837`)은 `암호를 입력하면 보호자 화면으로 전환돼요`다.
  // `입력하면`은 시안을 따르고, 끝은 **능동형**으로 둔다 — 피동형(`전환돼요`)은
  // 루트 CLAUDE.md 말투 규칙이 금지한다.
  child('암호를 입력하면 이룸이 화면으로 바뀌어요', Routes.child),
  guardian('암호를 입력하면 보호자 화면으로 바뀌어요', Routes.guardian);

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
