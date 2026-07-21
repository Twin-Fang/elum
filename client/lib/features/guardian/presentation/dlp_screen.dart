import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../application/routine_notifier.dart';

/// AI DLP 전/후 비교 — 발표의 보안 와우 포인트.
///
/// "아이를 이해하기 위해, AI가 아이의 개인정보까지 알 필요는 없습니다."
///
/// 화면에 표시하는 것은 **탐지 유형**뿐이다. 어떤 값이 탐지됐는지는 남기지 않는다.
class DlpScreen extends ConsumerStatefulWidget {
  const DlpScreen({super.key});

  @override
  ConsumerState<DlpScreen> createState() => _DlpScreenState();
}

class _DlpScreenState extends ConsumerState<DlpScreen> {
  @override
  void initState() {
    super.initState();
    // 화면에 들어오자마자 마스킹을 시작한다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routineFlowProvider.notifier).runDlp();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routineFlowProvider);
    final isProcessing = state.step == RoutineFlowStep.masking;

    return ElumScaffold(
      bottomButton: isProcessing
          ? null
          : ElumButton(
              label: '다음',
              onPressed: () {
                ref.read(routineFlowProvider.notifier).askQuestion();
                context.push(Routes.routineQuestion);
              },
            ),
      child: isProcessing
          ? const _MaskingIndicator()
          : _MaskResult(
              raw: state.rawInput,
              masked: state.maskedInput,
              types: state.detectedTypes,
            ),
    );
  }
}

/// 처리 중 연출. 최소 노출 시간은 notifier가 보장한다.
class _MaskingIndicator extends StatelessWidget {
  const _MaskingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.brandOrange),
          SizedBox(height: context.space.lg),
          Text(
            '개인정보를 보호하고 있어요',
            style: context.typo.subtitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: context.space.xs),
          Text(
            'AI에 보내기 전에 민감한 정보를 지워요',
            style: context.typo.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MaskResult extends StatelessWidget {
  const _MaskResult({
    required this.raw,
    required this.masked,
    required this.types,
  });

  final String raw;
  final String masked;
  final List<String> types;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final hasDetection = types.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            title: hasDetection ? '개인정보를\n보호했어요' : '안전하게\n준비했어요',
            description: hasDetection
                ? 'AI에는 아래 문장만 전달돼요'
                : '민감한 정보가 발견되지 않았어요',
          ),
          SizedBox(height: space.lg),

          if (hasDetection) ...[
            Wrap(
              spacing: space.xs,
              runSpacing: space.xs,
              children: [
                for (final type in types) _TypeChip(label: type),
              ],
            ),
            SizedBox(height: space.lg),
          ],

          _TextBlock(
            label: '보호자님이 입력한 내용',
            text: raw,
            background: colors.surface,
            borderColor: colors.border,
          ),
          SizedBox(height: space.sm),
          Center(
            child: Icon(Icons.arrow_downward, color: colors.textSecondary),
          ),
          SizedBox(height: space.sm),
          _TextBlock(
            label: 'AI에게 전달되는 내용',
            text: masked,
            background: colors.selectedFill,
            borderColor: colors.selectedBorder,
          ),
        ],
      ),
    );
  }
}

/// 탐지된 **유형**만 표시한다. 탐지된 값 자체는 보여주지 않는다.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.sm,
        vertical: context.space.xs,
      ),
      decoration: BoxDecoration(
        color: colors.selectedFill,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: colors.selectedBorder),
      ),
      child: Text(
        '$label 보호됨',
        style: context.typo.body.copyWith(
          color: colors.textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.label,
    required this.text,
    required this.background,
    required this.borderColor,
  });

  final String label;
  final String text;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.typo.body.copyWith(
            color: context.colors.textSecondary,
            fontSize: 14,
          ),
        ),
        SizedBox(height: space.xs),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(space.md),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(space.cardRadius),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            text,
            style: context.typo.body.copyWith(
              color: context.colors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
