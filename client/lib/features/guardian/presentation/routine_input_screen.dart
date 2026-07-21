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

/// 자연어 일과 입력.
///
/// 데모 안전 수칙: 추천 문장을 눌러 자동 입력한다.
/// 발표 중 타이핑하다 오타가 나면 흐름이 끊긴다.
class RoutineInputScreen extends ConsumerStatefulWidget {
  const RoutineInputScreen({super.key});

  @override
  ConsumerState<RoutineInputScreen> createState() => _RoutineInputScreenState();
}

class _RoutineInputScreenState extends ConsumerState<RoutineInputScreen> {
  late final TextEditingController _controller;

  /// 데모 시나리오 (docs/README.md 페르소나)
  static const _suggestion =
      '내일 비가 많이 올 예정이야. 아이가 학교에 갈 수 있게 준비해야 해.';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(routineFlowProvider).rawInput,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routineFlowProvider);
    final notifier = ref.read(routineFlowProvider.notifier);
    final colors = context.colors;
    final space = context.space;

    return ElumScaffold(
      onBack: () => context.pop(),
      bottomButton: ElumButton(
        label: '카드 만들기',
        onPressed: state.rawInput.trim().isEmpty
            ? null
            : () => context.push(Routes.routineMasking),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ElumHeader(
              title: '어떤 일과를\n준비할까요?',
              description: '평소 말하듯이 적어주세요',
            ),
            SizedBox(height: space.xl),
            Container(
              padding: EdgeInsets.all(space.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(space.cardRadius),
                border: Border.all(color: colors.border),
              ),
              child: TextField(
                controller: _controller,
                onChanged: notifier.setRawInput,
                maxLines: 5,
                style: context.typo.body.copyWith(color: colors.textPrimary),
                decoration: InputDecoration.collapsed(
                  hintText: '예) 내일 아침에 병원에 가야 해',
                  hintStyle: context.typo.body
                      .copyWith(color: colors.textPlaceholder),
                ),
              ),
            ),
            SizedBox(height: space.md),
            _SuggestionChip(
              text: _suggestion,
              onTap: () {
                _controller.text = _suggestion;
                notifier.setRawInput(_suggestion);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        padding: EdgeInsets.all(space.sm),
        decoration: BoxDecoration(
          color: colors.highlightFill,
          borderRadius: BorderRadius.circular(space.cardRadius),
          border: Border.all(color: colors.highlightBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: colors.brandOrange),
            SizedBox(width: space.xs),
            Expanded(
              child: Text(
                text,
                style: context.typo.bodySmall
                    .copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
