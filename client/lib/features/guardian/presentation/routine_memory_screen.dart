import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/pro_teaser.dart';
import '../../../core/widgets/settings_group.dart';
import '../../../core/widgets/settings_switch_tile.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../../core/widgets/show_failure.dart';
import '../../member/application/plan_access.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../application/routine_memory_controller.dart';
import '../domain/routine_memory.dart';
import 'pro_teaser_samples.dart';
import 'routine_memory_line_sheet.dart';

/// 이룸이별 AI 메모 화면 (Pro, 시안 없음 — 설정 묶음 카드 모양을 따름)
/// 묶음 3개: 켜기/끄기 > 메모 줄(누르면 고치기·지우기, 더하기) > 모두 지우기
/// 상태: 불러오는 중 / 실패(다시 하기 + 에러 코드) / 메모 / (Free · 판매 중) 흐린 견본 메모 — 서버를 부르지 않음
class RoutineMemoryScreen extends ConsumerWidget {
  const RoutineMemoryScreen({super.key});

  /// 설정 화면들과 같은 제목 줄 y · 첫 묶음까지 · 묶음 사이
  static const _titleRowTop = 67.0;
  static const _topGap = 24.0;
  static const _groupGap = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(planAccessProvider);
    final body = !access.canUseRoutineMemory && access.shouldShowProTeaser
        ? _proTeaser(context, ref)
        : _memoryBody(context, ref);

    return ElumScaffold(
      onBack: context.popOrHome,
      title: context.l10n.routineMemoryTitle,
      backTop: _titleRowTop,
      horizontalPadding: 16,
      child: body,
    );
  }

  Widget _proTeaser(BuildContext context, WidgetRef ref) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: _topGap.h, bottom: _topGap.h),
          child: ProTeaser(
            benefit: context.l10n.proTeaserRoutineMemoryBenefit,
            onUnlock: () => openPlanPaywall(context, ref),
            child: ProTeaserSamples.routineMemory(context),
          ),
        ),
      );

  Widget _memoryBody(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(routineMemoryControllerProvider)) {
      AsyncData(value: final memory) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(top: _topGap.h, bottom: _topGap.h),
            child: _RoutineMemoryGroups(memory: memory),
          ),
        ),
      AsyncError(:final error) => ElumStateBody(
          child: ElumErrorView.failure(
            error,
            fallback: context.l10n.routineMemoryLoadFailed,
            fallbackCode: 'E-MEMORY-LOAD',
            onRetry: ref.read(routineMemoryControllerProvider.notifier).reload,
          ),
        ),
      _ => const ElumStateBody.loading(),
    };
  }
}

class _RoutineMemoryGroups extends ConsumerWidget {
  const _RoutineMemoryGroups({required this.memory});

  final RoutineMemory memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(routineMemoryControllerProvider.notifier);
    final gap = SizedBox(height: RoutineMemoryScreen._groupGap.h);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          footer: l10n.routineMemoryEnabledFooter,
          children: [
            SettingsSwitchTile(
              label: l10n.routineMemoryEnabledLabel,
              value: memory.isEnabled,
              onChanged: (isOn) => _runSave(context, () => controller.setEnabled(isOn)),
            ),
          ],
        ),
        gap,
        SettingsGroup(
          header: l10n.routineMemoryLinesHeader(memory.lines.length, RoutineMemory.maxLineCount),
          footer: memory.lines.isEmpty ? l10n.routineMemoryEmptyFooter : l10n.routineMemoryLinesFooter,
          children: [
            if (memory.lines.isEmpty) SettingsTile(label: l10n.routineMemoryEmpty, onTap: null, valueText: ''),
            for (final (index, line) in memory.lines.indexed)
              SettingsTile(
                label: line.text,
                valueText: line.isWrittenByGuardian ? l10n.routineMemoryWrittenByMe : null,
                showChevronWithValue: true,
                onTap: () => _editLine(context, controller, index, line.text),
              ),
            if (memory.canAddLine)
              SettingsTile(label: l10n.routineMemoryAddLine, onTap: () => _addLine(context, controller)),
          ],
        ),
        // 지울 줄이 없으면 묶음째 숨김 (누를 수 없는 위험 줄을 남기지 않게)
        if (memory.lines.isNotEmpty) ...[
          gap,
          SettingsGroup(
            footer: l10n.routineMemoryClearFooter,
            children: [
              SettingsTile(
                label: l10n.routineMemoryClearAll,
                destructive: true,
                onTap: () => _confirmClear(context, controller),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 줄 누름 > 시트 > 저장이면 그 자리 바꿈, 지우기면 그 줄 지움
  Future<void> _editLine(BuildContext context, RoutineMemoryController controller, int index, String text) async {
    final sheetResult = await showRoutineMemoryLineSheet(context, currentText: text);
    if (sheetResult == null || !context.mounted) return;
    await _runSave(context, () => switch (sheetResult) {
          RoutineMemoryLineSaved(:final text) => controller.replaceLine(index, text),
          RoutineMemoryLineDeleted() => controller.removeLine(index),
        });
  }

  Future<void> _addLine(BuildContext context, RoutineMemoryController controller) async {
    final sheetResult = await showRoutineMemoryLineSheet(context);
    if (sheetResult is! RoutineMemoryLineSaved || !context.mounted) return;
    await _runSave(context, () => controller.addLine(sheetResult.text));
  }

  /// 되돌릴 수 없으니 팝업으로 한 번 묻는다
  Future<void> _confirmClear(BuildContext context, RoutineMemoryController controller) async {
    final l10n = context.l10n;
    final isConfirmed = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: l10n.routineMemoryClearConfirmTitle,
      message: l10n.routineMemoryClearConfirmMessage,
      actions: [
        ElumDialogAction(label: l10n.commonCancel, value: false, tone: ElumDialogTone.neutral),
        ElumDialogAction(label: l10n.commonConfirm, value: true, tone: ElumDialogTone.danger),
      ],
    );
    if (isConfirmed != true || !context.mounted) return;
    await _runSave(context, controller.clearAll);
  }

  /// 저장 공통: 실패면 서버 문구(진단 낱말 거절 등)를 팝업으로, 에러 코드 함께
  Future<void> _runSave(BuildContext context, Future<Object?> Function() save) async {
    final failure = await save();
    if (failure == null || !context.mounted) return;
    await showFailure(
      context,
      failure,
      title: context.l10n.routineMemorySaveFailedTitle,
      fallback: context.l10n.routineMemorySaveFailedFallback,
      fallbackCode: 'E-MEMORY-SAVE',
    );
  }
}
