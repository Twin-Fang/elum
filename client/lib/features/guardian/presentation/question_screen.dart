import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../application/routine_notifier.dart';

/// AI 추가 질문 — 생활 맥락이 부족할 때 보호자에게 되묻는다.
///
/// "가방을 챙겨요" 카드가 있어도 병원엔 진료카드, 학교엔 필통처럼
/// 준비물이 상황마다 다르다. 그 맥락은 보호자만 안다.
class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routineFlowProvider);
    final notifier = ref.read(routineFlowProvider.notifier);
    final question = state.question;

    // 질문 로딩 중이거나 카드 생성 중
    if (question == null || state.step == RoutineFlowStep.generating) {
      return const ElumScaffold(child: _Loading());
    }

    return ElumScaffold(
      bottomButton: ElumButton(
        label: '카드 만들기',
        onPressed: () {
          notifier.generateCards();
          context.push(Routes.routineReview);
        },
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              title: question.question ?? '',
              description: '해당하는 것을 골라주세요 (건너뛰어도 괜찮아요)',
            ),
            SizedBox(height: context.space.xl),
            for (final option in question.options)
              _OptionChip(
                label: option,
                isSelected: state.answers.contains(option),
                onTap: () => notifier.toggleAnswer(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: context.colors.brandOrange),
          SizedBox(height: context.space.lg),
          Text(
            '카드를 만들고 있어요',
            style: context.typo.subtitle
                .copyWith(color: context.colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: space.sm),
        padding: EdgeInsets.all(space.md),
        decoration: BoxDecoration(
          color: isSelected ? colors.goalSelectedFill : colors.surface,
          borderRadius: BorderRadius.circular(space.cardRadius),
          border: Border.all(
            color: isSelected ? colors.goalSelectedBorder : colors.border,
            width: isSelected
                ? space.selectedBorderWidth
                : space.borderWidth,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? colors.goalSelectedBorder : colors.border,
            ),
            SizedBox(width: space.sm),
            Text(
              label,
              style: context.typo.body.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
