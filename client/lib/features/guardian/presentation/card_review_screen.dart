import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../shared/models/action_card.dart';
import '../application/routine_notifier.dart';

/// 카드 검토·승인.
///
/// **승인 전에는 아동 화면에 노출되지 않는다** (docs 원칙 3번).
/// AI가 만든 결과를 보호자가 확인하는 "출력 승인" 단계다.
class CardReviewScreen extends ConsumerWidget {
  const CardReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routineFlowProvider);
    final notifier = ref.read(routineFlowProvider.notifier);
    final routine = state.routine;

    if (routine == null || state.step == RoutineFlowStep.generating) {
      return ElumScaffold(
        child: Center(
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
        ),
      );
    }

    return ElumScaffold(
      bottomButton: ElumButton(
        label: '이 카드로 시작하기',
        onPressed: () async {
          await notifier.confirm();
          if (context.mounted) context.go(Routes.child);
        },
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              title: routine.title.isEmpty ? '카드가 준비됐어요' : routine.title,
              description: '내용을 확인하고 수정할 수 있어요',
            ),
            SizedBox(height: context.space.xl),
            for (final card in routine.steps)
              _CardTile(
                card: card,
                onEdit: (text) => notifier.updateStep(card.id, text),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onEdit});

  final ActionCard card;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return Container(
      margin: EdgeInsets.only(bottom: space.sm),
      padding: EdgeInsets.all(space.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          // 순서 배지
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.highlightFill,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${card.stepOrder}',
              style: context.typo.body.copyWith(color: colors.textPrimary),
            ),
          ),
          SizedBox(width: space.sm),
          Expanded(
            child: Text(
              card.description,
              style: context.typo.body.copyWith(color: colors.textPrimary),
            ),
          ),
          IconButton(
            onPressed: () => _showEditSheet(context),
            icon: Icon(Icons.edit_outlined, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final controller = TextEditingController(text: card.description);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: context.space.lg,
          right: context.space.lg,
          top: context.space.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + context.space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '카드 내용 수정',
              style: context.typo.subtitle
                  .copyWith(color: context.colors.textPrimary),
            ),
            SizedBox(height: context.space.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              style: context.typo.body
                  .copyWith(color: context.colors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.colors.surface,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(context.space.fieldRadius),
                  borderSide: BorderSide(color: context.colors.border),
                ),
              ),
            ),
            SizedBox(height: context.space.md),
            ElumButton(
              label: '수정하기',
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) onEdit(text);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
