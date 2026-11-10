import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/elum_text_link.dart';
import '../../../member/application/plan_access.dart';
import '../../application/routine_memory_controller.dart';
import '../../data/routine_memory_repository.dart';
import '../../domain/routine_memory.dart';
import 'routine_memory_labels.dart';

/// 일과를 고쳐서 보낸 직후: AI 가 찾은 수정을 물어보는 시트 (Pro + 메모리 켜짐일 때만)
///
/// 관찰 조회를 [_pollInterval] 간격으로 최대 [_maxPolls] 번 물어 READY 이고 관찰 중(WATCHING)인 항목이 있으면 보임.
/// PENDING 이 끝까지 이어지거나 실패하면 아무것도 안 보임 (화면을 막지 않음). 보내는 화면이 사라진 뒤라 [rootContext] 로 띄움
Future<void> showMemoryObservationsAfterSend(BuildContext rootContext, String routineId) async {
  final container = ProviderScope.containerOf(rootContext, listen: false);
  try {
    if (!container.read(planAccessProvider).canUseRoutineMemory) return;
    final memory = await container.read(routineMemoryControllerProvider.future);
    if (!memory.isEnabled) return;
    final repository = container.read(routineMemoryRepositoryProvider);
    for (var attempt = 0; attempt < _maxPolls; attempt++) {
      final observations = await repository.fetchObservations(routineId);
      if (observations.status == MemoryObservationStatus.none) return;
      final watching = [for (final item in observations.items) if (item.ruleStatus == MemoryRuleStatus.watching) item];
      if (observations.status == MemoryObservationStatus.ready) {
        if (watching.isEmpty || !rootContext.mounted) return;
        await showElumSheet<void>(context: rootContext, builder: (_) => _ObservationSheet(items: watching));
        return;
      }
      await Future<void>.delayed(_pollInterval);
    }
  } catch (error, stack) {
    // 이 안내는 덤이라 실패해도 조용히 (로그만)
    AppLogger.error('routine memory', error, stack, {'step': 'observations'});
  }
}

const _maxPolls = 4;
const _pollInterval = Duration(seconds: 2);

/// 카드에 보이는 최대 개수 (나머지는 `AI 메모리에서 N개 더 보기`)
const _maxVisibleCards = 2;

class _ObservationSheet extends StatelessWidget {
  const _ObservationSheet({required this.items});

  final List<MemoryObservation> items;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final visible = items.take(_maxVisibleCards).toList();
    final restCount = items.length - visible.length;
    return ElumSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in visible) ...[
            _ObservationCard(item: item),
            SizedBox(height: space.sm.h),
          ],
          if (restCount > 0)
            ElumTextLink(
              label: context.l10n.memoryObsMore(restCount),
              onTap: () {
                Navigator.of(context).pop();
                context.push(Routes.guardianRoutineMemory);
              },
            ),
        ],
      ),
    );
  }
}

/// 카드 하나: `AI 메모리` > 바꾸기 전후 > 질문 > `항상 이렇게`(규칙으로 적용) · `이번만`(닫기). 적용하면 카드가 확정 문구로 바뀜
class _ObservationCard extends ConsumerStatefulWidget {
  const _ObservationCard({required this.item});

  final MemoryObservation item;

  @override
  ConsumerState<_ObservationCard> createState() => _ObservationCardState();
}

enum _CardState { asking, saving, applied, dismissed }

class _ObservationCardState extends ConsumerState<_ObservationCard> {
  _CardState _state = _CardState.asking;

  Future<void> _applyAlways() async {
    setState(() => _state = _CardState.saving);
    try {
      await ref.read(routineMemoryRepositoryProvider).setRuleStatus(widget.item.ruleId, MemoryRuleStatus.active);
      ref.invalidate(routineMemoryControllerProvider);
      if (mounted) setState(() => _state = _CardState.applied);
    } catch (error, stack) {
      // 저장 실패: 다시 눌러 볼 수 있게 질문 상태로 되돌림
      AppLogger.error('routine memory', error, stack, {'step': 'applyObservation'});
      if (mounted) setState(() => _state = _CardState.asking);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _CardState.dismissed) return const SizedBox.shrink();
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final item = widget.item;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(space.cardRadius.r)),
      child: Padding(
        padding: EdgeInsets.all(space.md.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.memoryObsTitle, style: context.typo.creditTitle.copyWith(color: colors.textPrimary)),
            SizedBox(height: space.sm.h),
            DecoratedBox(
              decoration: BoxDecoration(color: colors.buttonNeutral, borderRadius: BorderRadius.circular(space.sm.r)),
              child: Padding(
                padding: EdgeInsets.all(space.sm.w),
                child: item.before != null && item.after != null && item.before!.isNotEmpty
                    ? Text.rich(
                        TextSpan(children: [
                          TextSpan(text: item.before, style: TextStyle(decoration: TextDecoration.lineThrough, color: colors.textSecondary)),
                          TextSpan(text: ' → ${item.after}'),
                        ]),
                        style: context.typo.creditHistoryRowTitle.copyWith(color: colors.textPrimary),
                      )
                    : Text(item.summary, style: context.typo.creditHistoryRowTitle.copyWith(color: colors.textPrimary)),
              ),
            ),
            SizedBox(height: space.sm.h),
            Text(
              _state == _CardState.applied ? l10n.memoryObsDone : l10n.memoryObsAsk(item.type.observationPhrase(l10n)),
              style: context.typo.creditBody.copyWith(color: colors.textPrimary),
            ),
            if (_state != _CardState.applied) ...[
              SizedBox(height: space.sm.h),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElumButton(
                      label: l10n.memoryObsAlways,
                      loading: _state == _CardState.saving,
                      onPressed: _state == _CardState.saving ? null : _applyAlways,
                    ),
                  ),
                  SizedBox(width: space.xs.w),
                  Expanded(
                    flex: 2,
                    child: ElumButton(
                      label: l10n.memoryObsOnce,
                      backgroundColor: colors.buttonNeutral,
                      labelColor: colors.buttonNeutralText,
                      onPressed: _state == _CardState.saving ? null : () => setState(() => _state = _CardState.dismissed),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
