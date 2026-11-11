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
import '../../member/domain/elumi_nickname_policy.dart';
import '../application/name_controller.dart';
import '../application/onboarding_notifier.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/logger/app_logger.dart';

/// Figma `온보딩_이름` — 아이 호칭을 받는다.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 뒤로 왔을 때 이전 입력 되살리기 (첫 프레임 뒤: initState 의 ref.read 는 빌드 중 provider 일정을 건드려 예외)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.text.isNotEmpty) return;
      final savedNickname = ref.read(onboardingProvider).childNickname;
      _controller.value = TextEditingValue(
        text: savedNickname,
        selection: TextSelection.collapsed(offset: savedNickname.length),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 다음 단계로 넘어간다.
  ///
  /// 로그인은 온보딩 앞에서 끝나므로 여기서는 **입력만 받는다.** 서버 저장은 온보딩을
  /// 마칠 때 [OnboardingNotifier.complete]가 한 번에 처리한다.
  void _submit() {
    context.push(Routes.onboardingExampleCategories);
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
      await ref.read(nameControllerProvider).clearSelectedRole();
    } catch (e, stack) {
      // 지우지 못해도 이동은 한다. 다음 시작 때 이 화면으로 돌아올 뿐이다.
      AppLogger.error('[onboarding name] role clear failed', e, stack);
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
        // 다른 보호자가 이미 만든 이룸이에 합류하는 길 (Figma 1532:7112, y=765).
        // 연결 암호의 `나중에 할게요`와 같은 모양이다. 합류하면 이룸이 등록은 건너뛴다.
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
              // 서버와 같은 상한 (공백 없는 긴 이름이 이룸이 화면을 깨뜨림 #1129)
              maxLength: ElumiNicknamePolicy.maxLength,
              // 입력 때 읽음 (빌드 중 ref.read 를 두지 않음)
              onChanged: (nickname) => ref.read(onboardingProvider.notifier).setNickname(nickname),
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
