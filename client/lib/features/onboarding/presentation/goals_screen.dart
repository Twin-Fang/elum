import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/selectable_group.dart';
import '../application/onboarding_notifier.dart';
import '../domain/support_goal.dart';
import 'widgets/goal_chip.dart';

/// Figma `온보딩_목표` — 도움 목표를 여러 개 고른다.
///
/// 진단명을 묻지 않고 개인화하는 서비스의 핵심 장치다.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return ElumScaffold(
      onBack: () => context.pop(),
      bottomButton: ElumButton(
        label: '다음',
        onPressed: profile.canProceedFromGoals
            ? () => context.push(Routes.onboardingCharacter)
            : null,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              // 앞 화면에서 받은 호칭을 그대로 쓴다
              title: '${profile.displayName}의 어떤 순간을\n도와주고 싶으신가요?',
              description: '여러 개를 선택할 수 있어요',
            ),
            SizedBox(height: context.space.xl),
            SelectableGroup<SupportGoal>(
              items: SupportGoal.values,
              selected: profile.supportGoals,
              multiSelect: true,
              onChanged: notifier.setGoals,
              itemBuilder: (context, goal, isSelected) =>
                  GoalChip(goal: goal, isSelected: isSelected),
            ),
          ],
        ),
      ),
    );
  }
}
