import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../application/onboarding_notifier.dart';

/// Figma `시작` — 서비스 진입 화면.
///
/// 로고는 Cloudsofa_namgim(64px) 폰트가 미확보라 텍스트로 대체한다.
/// 폰트나 로고 에셋이 확보되면 이 부분만 교체하면 된다.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(localStorageProvider);
    // 이미 온보딩을 마쳤으면 다시 묻지 않는다
    final isDone = storage.isOnboardingCompleted;

    return ElumScaffold(
      bottomButton: ElumButton(
        label: isDone ? '시작하기' : '시작하기',
        onPressed: () => context.go(
          isDone ? Routes.guardian : Routes.onboardingName,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '이룸',
              style: context.typo.title.copyWith(
                fontSize: 64,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: context.space.sm),
            Text(
              '아이가 스스로 해내는 하루',
              style: context.typo.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
