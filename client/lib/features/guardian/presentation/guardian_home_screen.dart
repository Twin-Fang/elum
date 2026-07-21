import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../application/routine_notifier.dart';

/// 보호자 홈 — 일과 입력 시작 지점.
class GuardianHomeScreen extends ConsumerWidget {
  const GuardianHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);

    return ElumScaffold(
      bottomButton: ElumButton(
        label: '일과 만들기',
        onPressed: () {
          // 새 일과를 시작할 때마다 이전 상태를 지운다
          ref.read(routineFlowProvider.notifier).reset();
          context.push(Routes.routineInput);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            title: '오늘은 ${profile.displayName}와\n무엇을 해볼까요?',
            description: '일과를 알려주시면 행동 카드로 만들어드려요',
          ),
          SizedBox(height: context.space.xl),
          _ChildModeCard(
            onTap: () => context.push(Routes.child),
          ),
        ],
      ),
    );
  }
}

/// 아동 모드 진입. 승인된 카드가 있을 때만 의미가 있다.
class _ChildModeCard extends StatelessWidget {
  const _ChildModeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(space.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(space.cardRadius),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.child_care, color: colors.brandOrange, size: 32),
            SizedBox(width: space.sm),
            Expanded(
              child: Text(
                '아이 모드로 전환',
                style: context.typo.body.copyWith(color: colors.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
