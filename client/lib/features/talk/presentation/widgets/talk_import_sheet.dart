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
import '../../../../core/widgets/elum_toast.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../guardian/application/library_talk_import_state.dart';
import '../../../guardian/application/routine_providers.dart';
import '../../../member/application/member_providers.dart';
import '../../../profile/application/profile_session.dart';
import '../../../profile/domain/profile_summary.dart';
import '../../application/talk_import_controller.dart';
import '../../domain/talk_post.dart';
import '../../domain/talk_screen_codes.dart';
import 'talk_choice_row.dart';
import 'talk_sheet_frame.dart';

/// 시트가 닫히며 돌려주는 값: 일과가 들어간 이룸이와 새 일과 id
typedef _ImportOutcome = ({ProfileSummary profile, String routineId});

/// "내 일과로": 글을 일과관리로 가져오는 시트 > 성공하면 토스트 "{호칭} 일과관리에 넣었어요 · 보러 가기"
/// 피드·상세가 이 함수만 부른다. 실패는 시트 안에서 안내하고 시트를 유지한다
Future<void> showTalkImportSheet(
  BuildContext context,
  WidgetRef ref,
  TalkPostSummary post,
) async {
  // 시트가 닫힌 뒤에도 쓸 것들을 먼저 잡는다 (화면이 사라져도 토스트·이동은 이어진다)
  final container = ProviderScope.containerOf(context);
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;

  final outcome = await showElumSheet<_ImportOutcome>(
    context: context,
    builder: (_) => TalkImportSheet(post: post),
  );
  if (outcome == null) return;

  showElumToastOn(
    messenger,
    l10n.talkImportDone(outcome.profile.displayName),
    actionLabel: l10n.talkImportGoToLibrary,
    onAction: () => _showImportedRoutine(container, router, outcome),
  );
}

/// 보러 가기: 넣은 이룸이로 바꾸고 > 스크롤 대상 지정 > 일과관리 칸으로
Future<void> _showImportedRoutine(
  ProviderContainer container,
  GoRouter router,
  _ImportOutcome outcome,
) async {
  container
      .read(libraryScrollTargetRoutineIdProvider.notifier)
      .request(outcome.routineId);
  try {
    await container
        .read(profileSessionProvider.notifier)
        .select(outcome.profile);
  } catch (e, stack) {
    // 이룸이를 못 바꿔도 일과관리 칸으로는 간다
    AppLogger.error('[talk import] profile select failed', e, stack);
  }
  router.go(Routes.guardianManage);
}

/// 가져오기 시트 본문: 이룸이(2명 이상일 때) > 묶음 > 취소 · 일과관리에 넣기, 연결된 이룸이가 없으면 연결 안내
class TalkImportSheet extends ConsumerStatefulWidget {
  const TalkImportSheet({super.key, required this.post});

  final TalkPostSummary post;

  @override
  ConsumerState<TalkImportSheet> createState() => _TalkImportSheetState();
}

class _TalkImportSheetState extends ConsumerState<TalkImportSheet> {
  /// 고른 이룸이 id. null 이면 지금 보는 이룸이
  String? _pickedProfileId;

  /// 고른 묶음 id. null 이면 묶음 없이
  String? _pickedGroupId;
  bool _isSubmitting = false;

  /// 연결된 이룸이 목록. 회원 정보를 못 받았으면 지금 보는 이룸이 하나
  List<ProfileSummary> _profiles() {
    final profiles = ref.watch(memberProvider).value?.profiles ?? const [];
    if (profiles.isNotEmpty) return profiles;
    final active = ref.watch(activeProfileProvider);
    return active == null ? const [] : [active];
  }

  Future<void> _submit(ProfileSummary profile, String? groupId) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final l10n = context.l10n;
    try {
      final result = await ref
          .read(talkImportControllerProvider)
          .importToLibrary(
            widget.post.id,
            profileId: profile.id,
            groupId: groupId,
          );
      if (!mounted) return;
      final outcome = (profile: profile, routineId: result.routineId);
      Navigator.of(context).pop(outcome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await showFailure(
        context,
        e,
        title: l10n.talkImportFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.importToLibrary,
      );
    }
  }

  /// 시트를 닫고 이룸이 연결 화면으로
  void _openLink() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(Routes.linkCode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profiles = _profiles();
    if (profiles.isEmpty) {
      return TalkSheetFrame(
        title: l10n.talkImportNoElumiTitle,
        child: ElumButton(
          label: l10n.talkImportNoElumiAction,
          labelStyle: context.typo.sheetActionLabel,
          onPressed: _openLink,
        ),
      );
    }

    final activeProfileId = ref.watch(activeProfileProvider)?.id;
    final selected =
        profiles.where((p) => p.id == _pickedProfileId).firstOrNull ??
        profiles.where((p) => p.id == activeProfileId).firstOrNull ??
        profiles.first;
    // 묶음은 지금 보는 이룸이 것만 받아 둔 목록이라, 다른 이룸이를 고르면 묶음 없이만 넣는다
    final groups = selected.id == activeProfileId
        ? ref.watch(routineGroupsProvider).value ?? const []
        : const [];
    final groupId = groups.any((g) => g.id == _pickedGroupId)
        ? _pickedGroupId
        : null;
    final colors = context.colors;
    final space = context.space;

    return TalkSheetFrame(
      title: l10n.talkImportSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.talkImportSheetHint,
            style: context.typo.body.copyWith(color: colors.textSecondary),
          ),
          if (profiles.length >= 2) ...[
            _SectionLabel(label: l10n.talkImportElumiLabel),
            for (final profile in profiles)
              _ChoiceGap(
                child: TalkChoiceRow(
                  label: profile.displayName,
                  isSelected: profile.id == selected.id,
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() => _pickedProfileId = profile.id),
                ),
              ),
          ],
          if (groups.isNotEmpty) ...[
            _SectionLabel(label: l10n.talkImportGroupLabel),
            _ChoiceGap(
              child: TalkChoiceRow(
                label: l10n.talkImportGroupNone,
                isSelected: groupId == null,
                onTap: _isSubmitting
                    ? null
                    : () => setState(() => _pickedGroupId = null),
              ),
            ),
            for (final group in groups)
              _ChoiceGap(
                child: TalkChoiceRow(
                  label: group.name,
                  isSelected: group.id == groupId,
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() => _pickedGroupId = group.id),
                ),
              ),
          ],
          SizedBox(height: space.md.h),
          Row(
            children: [
              Expanded(
                child: ElumButton(
                  label: l10n.commonCancel,
                  labelStyle: context.typo.sheetActionLabel,
                  backgroundColor: colors.buttonNeutral,
                  labelColor: colors.buttonNeutralText,
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: space.xs.w),
              Expanded(
                flex: 2,
                child: ElumButton(
                  label: l10n.talkImportConfirm,
                  labelStyle: context.typo.sheetActionLabel,
                  loading: _isSubmitting,
                  onPressed: () => _submit(selected, groupId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 고르기 구역 이름 (위에 간격)
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Padding(
      padding: EdgeInsets.only(top: space.md.h, bottom: space.xs.h),
      child: Text(
        label,
        style: context.typo.tileLabel.copyWith(
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

/// 고르기 줄 사이 간격
class _ChoiceGap extends StatelessWidget {
  const _ChoiceGap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.space.xs.h),
    child: child,
  );
}
