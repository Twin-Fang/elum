import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_effects.dart';
import '../../../core/router/pop_or_home.dart';
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
import '../../subscription/domain/plan_benefit.dart';
import '../../../core/widgets/elum_danger_confirm_dialog.dart';

/// 이룸이별 AI 메모 화면 (Pro, 시안 없음 — 설정 묶음 카드 모양을 따름)
/// 묶음 3개: 켜기/끄기 > 메모 줄(누르면 고치기·지우기, 더하기) > 모두 지우기
/// 상태: 불러오는 중 / 실패(다시 하기 + 에러 코드) / 메모 / (Free · 판매 중) 흐린 견본 메모 — 서버를 부르지 않음
class RoutineMemoryScreen extends ConsumerWidget {
  const RoutineMemoryScreen({super.key});

  /// 설정 화면들과 같은 제목 줄 y · 첫 묶음까지 · 묶음 사이
  static const _titleRowTop = ElumScaffold.settingsBackTop;
  static const _topGap = 24.0;
  static const _groupGap = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(planAccessProvider);
    final body = access.shouldShowTeaserFor(PlanBenefit.routineMemory)
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
      // 서버 Pro 거절(ROUTINE_MEMORY_PRO_REQUIRED · Pro 가 막 끝남): 실패 대신 미리 보기 (판매 중일 때)
      AsyncError(:final error) when isProOnlyRejection(error) && ref.watch(planAccessProvider).shouldPromoteBenefit(PlanBenefit.routineMemory) =>
        _proTeaser(context, ref),
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
          // 꺼짐: 켜짐 설명 대신 '꺼져 있어요' 한 줄 (아래 메모 줄은 흐리게)
          footer: memory.isEnabled ? l10n.routineMemoryEnabledFooter : l10n.routineMemoryDisabledFooter,
          children: [
            SettingsSwitchTile(
              label: l10n.routineMemoryEnabledLabel,
              value: memory.isEnabled,
              onChanged: (isOn) => _runSave(context, ref, () => controller.setEnabled(isOn)),
            ),
          ],
        ),
        gap,
        Opacity(
          opacity: memory.isEnabled ? 1 : AppEffects.inactiveContentOpacity,
          child: SettingsGroup(
            header: l10n.routineMemoryLinesHeader(memory.lines.length, RoutineMemory.maxLineCount),
            footer: _linesFooter(l10n),
            children: [
              if (memory.lines.isEmpty) SettingsTile(label: l10n.routineMemoryEmpty, onTap: null, valueText: ''),
              for (final (index, line) in memory.lines.indexed)
                SettingsTile(
                  label: line.text,
                  valueText: line.isWrittenByGuardian ? l10n.routineMemoryWrittenByMe : null,
                  showChevronWithValue: true,
                  onTap: () => _editLine(context, ref, controller, index, line.text),
                ),
              if (memory.canAddLine)
                SettingsTile(label: l10n.routineMemoryAddLine, onTap: () => _addLine(context, ref, controller)),
            ],
          ),
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
                onTap: () => _confirmClear(context, ref, controller),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 묶음 아래 설명: 0줄 > 처음 안내 · 가득 참 > 최대 개수 안내 (더하기 줄이 사라진 이유) · 그 외 > 고치기 안내
  String _linesFooter(AppLocalizations l10n) {
    if (memory.lines.isEmpty) return l10n.routineMemoryEmptyFooter;
    if (!memory.canAddLine) return l10n.routineMemoryFullFooter(RoutineMemory.maxLineCount);
    return l10n.routineMemoryLinesFooter;
  }

  /// 줄 누름 > 시트 > 저장이면 그 자리 바꿈, 지우기면 그 줄 지움
  Future<void> _editLine(BuildContext context, WidgetRef ref, RoutineMemoryController controller, int index, String text) async {
    final sheetResult = await showRoutineMemoryLineSheet(context, currentText: text);
    if (sheetResult == null || !context.mounted) return;
    await _runSave(context, ref, () => switch (sheetResult) {
          RoutineMemoryLineSaved(:final text) => controller.replaceLine(index, text),
          RoutineMemoryLineDeleted() => controller.removeLine(index),
        });
  }

  Future<void> _addLine(BuildContext context, WidgetRef ref, RoutineMemoryController controller) async {
    final sheetResult = await showRoutineMemoryLineSheet(context);
    if (sheetResult is! RoutineMemoryLineSaved || !context.mounted) return;
    await _runSave(context, ref, () => controller.addLine(sheetResult.text));
  }

  /// 되돌릴 수 없으니 팝업으로 한 번 묻는다
  Future<void> _confirmClear(BuildContext context, WidgetRef ref, RoutineMemoryController controller) async {
    final l10n = context.l10n;
    // 한 번 확인 (일과·기록·별은 남고 메모는 다음 일과부터 다시 쌓임 — 입력 확인까지는 아님, #1171)
    final isConfirmed = await confirmDangerousAction(
      context,
      icon: ElumDangerIcon.trash,
      title: l10n.routineMemoryClearConfirmTitle,
      message: l10n.routineMemoryClearConfirmMessage,
      actionLabel: l10n.routineMemoryClearConfirmAction,
    );
    if (!isConfirmed || !context.mounted) return;
    await _runSave(context, ref, controller.clearAll);
  }

  /// 저장 공통: 실패면 서버 문구(진단 낱말 거절 등)를 팝업으로, 에러 코드 함께
  Future<void> _runSave(BuildContext context, WidgetRef ref, Future<Object?> Function() save) async {
    final failure = await save();
    if (failure == null || !context.mounted) return;
    if (await handleProOnlyRejection(context, ref, failure)) return;
    if (!context.mounted) return;
    await showFailure(
      context,
      failure,
      title: context.l10n.routineMemorySaveFailedTitle,
      fallback: context.l10n.routineMemorySaveFailedFallback,
      fallbackCode: 'E-MEMORY-SAVE',
    );
  }
}
