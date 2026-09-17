import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_text_field.dart';
import '../application/onboarding_notifier.dart';

/// Figma `온보딩_이름` — 아이 호칭을 받는다.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // 뒤로 왔을 때 이전 입력이 남아있어야 한다
    _controller = TextEditingController(
      text: ref.read(onboardingProvider).childNickname,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 다음 단계로 넘어간다.
  ///
  /// 예전에는 이 화면이 로그인까지 했다(아이 이름 = 아이디). 지금은 로그인이
  /// 온보딩 앞으로 나갔으므로 여기서는 **입력만 받는다.** 서버 저장은 온보딩을
  /// 마칠 때 [OnboardingNotifier.complete]가 한 번에 처리한다.
  void _submit() {
    context.push(Routes.onboardingGoals);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingProvider);
    final canSubmit = profile.canProceedFromName;

    return ElumScaffold(
      bottomButton: ElumButton(
        label: '다음',
        // 진행 조건은 모델이 안다 — 화면마다 재구현하지 않는다
        onPressed: canSubmit ? _submit : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ElumHeader(
            title: '아이를 어떻게\n불러드릴까요?',
            // 개인정보 최소수집 원칙의 UI 표현 — 삭제하지 않는다
            description: '정확한 실명이 아니어도 괜찮아요',
          ),
          // Figma 설명 하단(227) → 입력 필드(279)
          SizedBox(height: context.space.headerToContent),
          ElumTextField(
            controller: _controller,
            hintText: '이름을 입력해주세요',
            onChanged: ref.read(onboardingProvider.notifier).setNickname,
            // 엔터는 키보드만 닫는다. 진행은 '다음' 버튼으로만 통일한다.
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ],
      ),
    );
  }
}
