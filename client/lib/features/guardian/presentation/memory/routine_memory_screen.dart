import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/share_origin.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/router/pop_or_home.dart';
import '../../../../core/theme/app_effects.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_danger_confirm_dialog.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_scaffold.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../../core/widgets/min_tap_target.dart';
import '../../../../core/widgets/pro_teaser.dart';
import '../../../../core/widgets/settings_switch_tile.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/domain/plan_benefit.dart';
import '../../application/guardian_child_identity.dart';
import '../../application/routine_memory_controller.dart';
import '../../data/card_export_files.dart';
import '../../data/routine_memory_repository.dart';
import '../../domain/routine_memory.dart';
import '../pro_teaser_samples.dart';
import 'routine_memory_hero_card.dart';
import 'routine_memory_line_sheet.dart';
import 'routine_memory_rows.dart';
import 'routine_memory_rule_sheet.dart';

/// 내 AI 메모리 (Pro): 위 카드(숫자 3칸) > 고른 칸의 목록 > (적용 중) 규칙 직접 적기 > 자동 찾기 스위치
///
/// 상태: 불러오는 중 / 실패(`E-MEMORY-LOAD` + 다시 하기) / 비었음(그림 + 안내) / 목록 / (Free · 판매 중) Pro 미리 보기 — 서버를 부르지 않음.
/// 고른 이룸이의 메모리이고 머리 제목의 이름으로 누구 것인지 보임
class RoutineMemoryScreen extends ConsumerStatefulWidget {
  const RoutineMemoryScreen({super.key});

  @override
  ConsumerState<RoutineMemoryScreen> createState() => _RoutineMemoryScreenState();
}

class _RoutineMemoryScreenState extends ConsumerState<RoutineMemoryScreen> {
  static const _titleRowTop = ElumScaffold.settingsBackTop;
  static const _topGap = 8.0;
  static const _sectionGap = 16.0;
  static const _exportFile = 'routine_memory.json';

  RoutineMemoryTab _tab = RoutineMemoryTab.applied;

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(planAccessProvider);
    return ElumScaffold(
      onBack: context.popOrHome,
      backTop: _titleRowTop,
      horizontalPadding: 16,
      child: access.shouldShowTeaserFor(PlanBenefit.routineMemory) ? _proTeaser(context) : _memoryBody(context),
    );
  }

  Widget _proTeaser(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: _sectionGap.h),
      child: ProTeaser(
        title: context.l10n.proTeaserRoutineMemoryTitle,
        benefit: context.l10n.proTeaserRoutineMemoryBenefit,
        actions: watchProUpsellActions(context, ref, highlight: PlanBenefit.routineMemory),
        child: ProTeaserSamples.routineMemory(context),
      ),
    ),
  );

  Widget _memoryBody(BuildContext context) {
    return switch (ref.watch(routineMemoryControllerProvider)) {
      AsyncData(value: final memory) => _data(context, memory),
      // 서버 Pro 거절(Pro 가 막 끝남): 실패 대신 미리 보기 (판매 중일 때)
      AsyncError(:final error) when isProOnlyRejection(error) && ref.watch(planAccessProvider).shouldPromoteBenefit(PlanBenefit.routineMemory) =>
        _proTeaser(context),
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

  Widget _data(BuildContext context, RoutineMemory memory) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final savedName = ref.watch(guardianChildIdentityProvider.select((identity) => identity.name));
    final elumiName = savedName.isEmpty ? l10n.commonElumiName : savedName;
    final controller = ref.read(routineMemoryControllerProvider.notifier);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(top: _topGap.h, bottom: _sectionGap.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerRight, child: _MenuButton(onTap: () => _openMenu(context, memory))),
            RoutineMemoryHeroCard(
              elumiName: elumiName,
              memory: memory,
              selectedTab: _tab,
              onTabSelected: (tab) => setState(() => _tab = tab),
            ),
            SizedBox(height: _sectionGap.h),
            // 자동 찾기가 꺼져 있으면 목록은 흐리게 (읽고 고칠 수는 있음)
            Opacity(
              opacity: memory.isEnabled ? 1 : AppEffects.inactiveContentOpacity,
              child: memory.hasNothing ? _EmptyBody() : _list(context, memory),
            ),
            if (_tab == RoutineMemoryTab.applied) ...[
              SizedBox(height: space.sm.h),
              Center(
                child: MinTapTarget(
                  child: AppPressable(
                    onTap: () => _addRule(context, controller),
                    child: Text(l10n.memoryAddRule, style: context.typo.settingsGroupLabel.copyWith(color: colors.textPrimary)),
                  ),
                ),
              ),
            ],
            SizedBox(height: space.md.h),
            _autoFindSwitch(context, memory, controller),
          ],
        ),
      ),
    );
  }

  /// 고른 탭의 머리 + 흰 카드 안 줄들
  Widget _list(BuildContext context, RoutineMemory memory) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final controller = ref.read(routineMemoryControllerProvider.notifier);
    final (header, hint, rows) = switch (_tab) {
      RoutineMemoryTab.applied => (l10n.memoryListAppliedHeader, l10n.memoryListAppliedHint, _ruleRows(context, memory.activeRules, memory, controller)),
      RoutineMemoryTab.watching => (l10n.memoryListWatchingHeader, l10n.memoryListWatchingHint, _ruleRows(context, memory.watchingRules, memory, controller)),
      RoutineMemoryTab.edits => (l10n.memoryListEditsHeader, null, [for (final edit in memory.edits) MemoryEditRow(edit: edit)]),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: space.xs.w),
          child: Row(
            children: [
              Expanded(child: Text(header, style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel))),
              if (hint != null) Text(hint, style: context.typo.creditCaption.copyWith(color: colors.textSecondary)),
            ],
          ),
        ),
        SizedBox(height: space.xs.h),
        if (rows.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: space.md.h),
            child: Text(
              _tab == RoutineMemoryTab.edits ? l10n.memoryEmptyEdits : l10n.memoryEmptyTitle,
              textAlign: TextAlign.center,
              style: context.typo.creditBody.copyWith(color: colors.textSecondary),
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(space.cardRadius.r)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: space.md.w, vertical: space.xs.h),
              child: Column(children: rows),
            ),
          ),
      ],
    );
  }

  List<Widget> _ruleRows(BuildContext context, List<MemoryRule> rules, RoutineMemory memory, RoutineMemoryController controller) => [
    for (final rule in rules)
      MemoryRuleRow(
        rule: rule,
        autoApplyCount: memory.autoApplyCount,
        onTap: () => _openRuleSheet(context, rule, controller),
        onSwitchChanged: (isOn) => _runSave(context, () => controller.setRuleStatus(rule.id, isOn ? MemoryRuleStatus.active : MemoryRuleStatus.off)),
      ),
  ];

  Widget _autoFindSwitch(BuildContext context, RoutineMemory memory, RoutineMemoryController controller) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          toggled: memory.isEnabled,
          label: l10n.memoryAutoFind,
          child: AppPressable(
            onTap: () => _runSave(context, () => controller.setEnabled(!memory.isEnabled)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.space.xs.w, vertical: context.space.xs.h),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.memoryAutoFind, style: context.typo.settingsTileLabel.copyWith(color: colors.textPrimary))),
                  IgnorePointer(child: SettingsToggle(isOn: memory.isEnabled)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.space.xs.w),
          child: Text(l10n.memoryAutoFindNote(memory.autoApplyCount), style: context.typo.creditCaption.copyWith(color: colors.textSecondary)),
        ),
      ],
    );
  }

  Future<void> _openRuleSheet(BuildContext context, MemoryRule rule, RoutineMemoryController controller) async {
    final action = await showMemoryRuleSheet(context, rule);
    if (action == null || !context.mounted) return;
    switch (action) {
      case MemoryRuleSheetAction.applyNow:
        await _runSave(context, () => controller.setRuleStatus(rule.id, MemoryRuleStatus.active));
      case MemoryRuleSheetAction.delete:
        await _runSave(context, () => controller.deleteRule(rule.id));
      case MemoryRuleSheetAction.edit:
        final edited = await showRoutineMemoryLineSheet(context, currentText: rule.summary);
        if (!context.mounted) return;
        switch (edited) {
          case RoutineMemoryLineSaved(:final text):
            await _runSave(context, () => controller.editRuleText(rule.id, text));
          case RoutineMemoryLineDeleted():
            await _runSave(context, () => controller.deleteRule(rule.id));
          case null:
            return;
        }
    }
  }

  Future<void> _addRule(BuildContext context, RoutineMemoryController controller) async {
    final result = await showRoutineMemoryLineSheet(context);
    if (result is! RoutineMemoryLineSaved || !context.mounted) return;
    await _runSave(context, () => controller.addRule(result.text));
  }

  /// 오른쪽 위 `···` 메뉴: 파일로 내보내기 · 메모리 모두 지우기 (파일에서 가져오기는 파일 고르기 패키지가 없어 뺌)
  Future<void> _openMenu(BuildContext context, RoutineMemory memory) async {
    final l10n = context.l10n;
    final choice = await showElumSheet<_MenuChoice>(
      context: context,
      builder: (sheetContext) => ElumSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuRow(label: l10n.memoryMenuExport, onTap: () => Navigator.of(sheetContext).pop(_MenuChoice.export)),
            _MenuRow(label: l10n.memoryMenuClear, isDanger: true, onTap: () => Navigator.of(sheetContext).pop(_MenuChoice.clear)),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _MenuChoice.export:
        await _export(context);
      case _MenuChoice.clear:
        await _confirmClear(context);
    }
  }

  Future<void> _export(BuildContext context) async {
    final l10n = context.l10n;
    final origin = shareOriginOf(context);
    try {
      final json = await ref.read(routineMemoryRepositoryProvider).exportJson();
      await const CardExportFiles().share(
        files: [(fileName: _exportFile, bytes: Uint8List.fromList(utf8.encode(json)), mimeType: 'application/json')],
        sharePositionOrigin: origin,
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      await showFailure(context, error, title: l10n.memoryExportFailed, fallback: l10n.routineMemorySaveFailedFallback, fallbackCode: 'E-MEMORY-EXPORT');
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final l10n = context.l10n;
    final isConfirmed = await confirmDangerousAction(
      context,
      icon: ElumDangerIcon.trash,
      title: l10n.routineMemoryClearConfirmTitle,
      message: l10n.routineMemoryClearConfirmMessage,
      actionLabel: l10n.routineMemoryClearConfirmAction,
    );
    if (!isConfirmed || !context.mounted) return;
    await _runSave(context, ref.read(routineMemoryControllerProvider.notifier).clearAll);
  }

  /// 저장 공통: 실패면 서버 문구를 팝업으로, 에러 코드 함께
  Future<void> _runSave(BuildContext context, Future<Object?> Function() save) async {
    final failure = await save();
    if (failure == null || !context.mounted) return;
    if (await handleProOnlyRejection(context, ref, failure)) return;
    if (!context.mounted) return;
    await showFailure(
      context,
      AppFailure.of(failure),
      title: context.l10n.routineMemorySaveFailedTitle,
      fallback: context.l10n.routineMemorySaveFailedFallback,
      fallbackCode: 'E-MEMORY-SAVE',
    );
  }
}

enum _MenuChoice { export, clear }

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});

  final VoidCallback onTap;

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MinTapTarget(
      child: AppPressable(
        onTap: onTap,
        semanticLabel: context.l10n.memoryMenuLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.buttonNeutral, shape: BoxShape.circle),
          child: SizedBox(
            width: _size.w,
            height: _size.w,
            child: Center(child: Text('···', style: context.typo.settingsGroupLabel.copyWith(color: colors.textPrimary))),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap, this.isDanger = false});

  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.space.sm.h, horizontal: context.space.xs.w),
        child: Text(label, style: context.typo.settingsTileLabel.copyWith(color: isDanger ? colors.dangerText : colors.textPrimary)),
      ),
    );
  }
}

/// 규칙·기록이 하나도 없음: 그림 + 안내
class _EmptyBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.lg.h),
      child: Text(
        context.l10n.memoryEmptyTitle,
        textAlign: TextAlign.center,
        style: context.typo.creditBody.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}
