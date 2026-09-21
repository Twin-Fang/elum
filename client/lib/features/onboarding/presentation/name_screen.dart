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

    // 역할 선택에서 push로 들어오면 돌아갈 수 있어야 한다 (이슈 #212).
    // 다만 스플래시·가드처럼 go로 갈아끼워 들어오는 길도 있어, 그때는 pop할 것이
    // 없다. canPop으로 갈라 **없는 버튼을 눌러 아무 일도 안 나는 상황**을 막는다.
    final canGoBack = context.canPop();

    return ElumScaffold(
      onBack: canGoBack ? () => context.pop() : null,
      bottomButton: ElumButton(
        label: '다음',
        // 진행 조건은 모델이 안다 — 화면마다 재구현하지 않는다
        onPressed: canSubmit ? _submit : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            // 시안(204:996) 문구 그대로. `부를까요`로 줄여 두었던 것을 되돌린다.
            title: '이룸이를 어떻게\n불러드릴까요?',
            // 개인정보 최소수집 원칙의 UI 표현 — 삭제하지 않는다
            description: '정확한 실명이 아니어도 괜찮아요',
            hasBackButton: canGoBack,
          ),
          // Figma 설명 하단(227) → 입력 필드(279)
          SizedBox(height: context.space.headerToContent),
          ElumTextField(
            controller: _controller,
            hintText: '이름을 입력해주세요',
            onChanged: ref.read(onboardingProvider.notifier).setNickname,
            // 완료 키로도 다음 단계로 간다.
            //
            // 키보드가 하단 '다음'을 덮고 있어서, 이름을 다 치고도 무엇을 눌러야
            // 할지 보이지 않는다. 키보드를 내리는 것만으로는 그 사실을 알 수 없다.
            // 이름이 비어 있으면 진행 조건을 만족하지 않으므로 닫기만 한다.
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
              if (ref.read(onboardingProvider).canProceedFromName) _submit();
            },
          ),
        ],
      ),
    );
  }
}
