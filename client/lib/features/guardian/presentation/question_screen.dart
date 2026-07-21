import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../shared/models/routine.dart';
import '../application/routine_notifier.dart';
import 'widgets/routine_flow_scaffold.dart';

/// Figma `보호자_새로운 일과 만들기_추가질문`(262:4766 / 262:4854).
///
/// AI가 생활 맥락을 되묻는다. "가방을 챙겨요" 카드가 있어도 병원엔 진료카드,
/// 학교엔 필통처럼 준비물이 상황마다 다르고 그 맥락은 보호자만 안다.
///
/// **서버가 질문을 여러 개 준다** — 선택한 도움 목표마다 하나씩이다.
/// Figma는 한 개만 그렸지만 실제로는 2개 이상 올 수 있어 세로로 이어 붙인다.
///
/// 두 프레임의 차이는 선택 여부다. 아무것도 고르지 않으면 CTA가 없고(262:4766),
/// 하나라도 고르면 `카드 만들기`가 나타난다(262:4854).
class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routineFlowProvider);
    final notifier = ref.read(routineFlowProvider.notifier);
    final questions = state.question?.askable ?? const <QuestionItem>[];
    final space = context.space;

    // 아직 질문을 받아오는 중이면 기다린다.
    // 응답 전에 건너뛰면 질문이 있어도 화면을 지나쳐 버린다.
    if (state.question == null) {
      return const RoutineFlowScaffold(child: _Waiting());
    }

    // 질문이 없으면 여기 있을 이유가 없다. 바로 카드 생성으로 보낸다.
    // (도움 목표를 고르지 않으면 서버가 빈 배열을 준다)
    if (questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pushReplacement(Routes.routineMasking);
      });
      return const RoutineFlowScaffold(child: SizedBox.shrink());
    }

    return RoutineFlowScaffold(
      onBack: () => context.pop(),
      // 답을 하나라도 골랐을 때만 CTA가 나타난다 (Figma 262:4854)
      bottomButton: state.answers.isEmpty
          ? null
          : ElumButton(
              label: '카드 만들기',
              onPressed: () => context.push(Routes.routineMasking),
            ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: space.lg),
            SvgPicture.asset(AppAssets.iconSparklesLarge, width: 30, height: 36),
            SizedBox(height: space.lg),
            for (final (index, item) in questions.indexed) ...[
              if (index > 0) SizedBox(height: space.xl),
              _QuestionBlock(
                item: item,
                selected: state.answers,
                onToggle: notifier.toggleAnswer,
              ),
            ],
            SizedBox(height: space.xl),
          ],
        ),
      ),
    );
  }
}

/// 질문 하나 — 제목 + 선택지 칩들.
class _QuestionBlock extends StatelessWidget {
  const _QuestionBlock({
    required this.item,
    required this.selected,
    required this.onToggle,
  });

  final QuestionItem item;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: space.screenH),
          child: Text(
            item.question,
            textAlign: TextAlign.center,
            style: context.typo.promptTitle
                .copyWith(color: context.colors.textPrimary),
          ),
        ),
        SizedBox(height: space.lg),
        // 선택지 길이가 제각각이라 Wrap이 자연스럽다.
        // 입력 화면의 추천 칩과 달리 Figma도 고정 배치가 아니다.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: space.screenH),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final option in item.options)
                _OptionChip(
                  label: option,
                  isSelected: selected.contains(option),
                  onTap: () => onToggle(option),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 선택지 칩 (Figma padding 10×16, r20, 반투명 유리).
///
/// 고르면 배경이 진해진다(Figma 262:4870 — `text_title` 채움).
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(space.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? colors.textPrimary : colors.glassChip,
              borderRadius: BorderRadius.circular(space.cardRadius),
            ),
            child: Text(
              label,
              style: context.typo.chipLabel.copyWith(
                color: isSelected ? colors.surface : colors.chipLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 질문을 받아오는 동안 잠깐 보이는 상태.
/// 빈 화면을 두면 앱이 멈춘 것처럼 보인다.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.colors.promptMuted,
        ),
      ),
    );
  }
}
