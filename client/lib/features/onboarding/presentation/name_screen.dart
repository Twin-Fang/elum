import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_text_field.dart';
import '../../auth/data/auth_repository.dart';
import '../application/onboarding_notifier.dart';

/// Figma `온보딩_이름` — 아이 호칭을 받는다.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  late final TextEditingController _controller;

  /// 로그인 진행 중. 중복 탭을 막는다.
  bool _isSubmitting = false;

  /// 실패 안내. 에러 코드를 함께 보여줘 제보를 추적할 수 있게 한다.
  String? _errorMessage;

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

  /// 이름으로 로그인한다. 아이 이름이 곧 아이디다 (이슈 #19).
  ///
  /// 새 이름이면 계정을 만들고 온보딩을 계속하고, 이미 있는 이름이면
  /// 기존 계정으로 복귀해 보호자 홈으로 바로 보낸다.
  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final name = ref.read(onboardingProvider).childNickname;
    final outcome = await ref.read(authRepositoryProvider).signInWithName(name);

    if (!mounted) return;

    switch (outcome) {
      case AuthOutcome.created:
        // 새 계정 — 온보딩을 이어서 한다
        context.push(Routes.onboardingGoals);
      case AuthOutcome.restored:
        // 기존 계정 — 이미 설정을 마친 사용자다. 홈으로 바로 보낸다.
        await ref.read(onboardingProvider.notifier).restoreCompleted(name);
        if (!mounted) return;
        context.go(Routes.guardian);
      case AuthOutcome.failed:
        setState(() {
          // 서버가 이름을 4자 이상으로 제한한다. 그 외 실패도 여기로 온다.
          _errorMessage = '이름으로 시작할 수 없어요. 4자 이상으로 다시 입력해주세요. (E-AUTH)';
        });
      case AuthOutcome.offline:
        setState(() {
          // 이름 문제가 아니다. 이름을 고치라고 안내하면 계속 헛수고를 하게 된다.
          _errorMessage = '인터넷 연결을 확인하고 다시 눌러주세요. (E-NET)';
        });
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingProvider);
    final canSubmit = profile.canProceedFromName && !_isSubmitting;

    return ElumScaffold(
      bottomButton: ElumButton(
        label: _isSubmitting ? '확인 중...' : '다음',
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
            leadingIconAssetPath: AppAssets.inputFieldIconChildName,
            onChanged: ref.read(onboardingProvider.notifier).setNickname,
            // 엔터는 키보드만 닫는다. 진행은 '다음' 버튼으로만 —
            // 이름 입력이 곧 계정 생성이라 오입력으로 진행되면 되돌리기 번거롭다.
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
          if (_errorMessage != null) ...[
            SizedBox(height: context.space.md),
            Text(
              _errorMessage!,
              // 아동도 볼 수 있는 화면이라 빨강·경고 아이콘을 쓰지 않는다
              style: context.typo.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
