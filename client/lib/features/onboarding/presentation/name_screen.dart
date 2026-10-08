import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_text_field.dart';
import '../application/onboarding_notifier.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/router/routes.dart';

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

  /// 돌아갈 화면이 있으면 pop. 없으면 고른 역할을 지우고 역할 선택으로 간다.
  /// 역할이 남아 있으면 가드·시작 화면이 다시 이 화면으로 되돌린다.
  Future<void> _goBack() async {
    if (context.canPop()) {
      context.popOrHome();
      return;
    }
    final router = GoRouter.of(context);
    try {
      await ref.read(localStorageProvider).clearSelectedRole();
    } catch (e) {
      // 지우지 못해도 이동은 한다. 다음 시작 때 이 화면으로 돌아올 뿐이다.
      debugPrint('역할 삭제 실패: $e');
    }
    router.go(Routes.roleSelect);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingProvider);
    final canSubmit = profile.canProceedFromName;

    // 어디로 들어왔든 뒤로 갈 수 있어야 한다. 스택이 없으면(앱 재시작·go 진입) pop 대신
    // 역할 선택으로 되돌린다 — 안 그러면 저장된 역할 때문에 이 화면에 갇힌다.
    final canPop = context.canPop();

    return PopScope(
      // 스택이 없을 때의 시스템 뒤로가기·스와이프는 앱 종료 대신 _goBack 으로 받는다
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: ElumScaffold(
        onBack: _goBack,
        bottomButton: ElumButton(
          label: context.l10n.commonNext,
          // 진행 조건은 모델이 안다 — 화면마다 재구현하지 않는다
          onPressed: canSubmit ? _submit : null,
        ),
        // 다른 보호자가 이미 만든 이룸이에 합류하는 길 (다중 보호자 #362 · E6). **임시 시안이다** —
        // 진입점을 어디에 둘지 시안이 정하지 않았다(역할 선택 vs 이 화면). CTA 아래 보조 동작 자리에
        // 연결 암호의 `나중에 할게요`와 같은 모양으로 둔다. 합류하면 이룸이 등록은 건너뛴다.
        belowButton: Center(
          child: AppPressable(
            onTap: () => context.push(Routes.inviteEnter),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.space.xs.h),
              child: Text(
                context.l10n.onboardingNameInviteLink,
                style: context.typo.linkLater.copyWith(
                  color: context.colors.linkLaterLabel,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              // 시안(204:996) 문구 그대로. `부를까요`로 줄여 두었던 것을 되돌린다.
              title: context.l10n.onboardingNameTitle,
              // 개인정보 최소수집 원칙의 UI 표현 — 삭제하지 않는다
              description: context.l10n.onboardingNameDescription,
              hasBackButton: true,
            ),
            // Figma 설명 하단(227) → 입력 필드(279)
            SizedBox(height: context.space.headerToContent),
            ElumTextField(
              controller: _controller,
              hintText: context.l10n.onboardingNameHint,
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
      ),
    );
  }
}
