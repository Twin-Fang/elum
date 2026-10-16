import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/guardians_controller.dart';
import '../application/profile_session.dart';
import '../data/profile_repository.dart';
import '../domain/guardian_member.dart';
import 'guardian_edit_sheet.dart';
import 'widgets/guardian_person_row.dart';
import 'widgets/people_action_card.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/kept_text.dart';
import '../../member/application/member_providers.dart';
import '../../../core/router/routes.dart';

/// 지금 보는 이룸이를 함께 돌보는 사람.
///
/// 서버가 알려 주는 것은 이룸이 안에서 불리는 **이름·구분·합류 순서**뿐이다 — 계정 ID·아이디는
/// 내려오지 않는다. 그래서 이 화면에도 나오지 않는다.
///
/// 목록은 이룸이마다 다르다. 이룸이를 바꾸면 이 화면을 다시 열어야 하고, 열 때마다 새로 받는다
/// (autoDispose) — 다른 휴대폰에서 누가 들어오거나 나갔을 수 있다.
final guardiansProvider = FutureProvider.autoDispose
    .family<List<Guardian>, String>((ref, profileId) async {
      final attempt = await ref.watch(profileRepositoryProvider).listGuardians(profileId);
      // 실패는 던져서 화면이 에러 코드와 다시 시도를 그리게 한다.
      if (!attempt.isOk) throw attempt.failure!;
      return attempt.value!;
    });

/// 함께하는 사람 화면.
///
/// ## 나가기는 되돌릴 수 없다
///
/// 확인 팝업이 **먼저 무엇이 사라지고 무엇이 남는지** 말한다. 확인하기 전에는 서버에 아무것도
/// 보내지 않는다. 마지막 보호자이면 이룸이도 사라진다고 알린다 — 몇 명인지 모르면(목록을
/// 못 받았으면) 마지막인지 말할 수 없으므로 나가기를 막는다.
class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key});

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen>
    with BusyStateMixin<GuardiansScreen> {
  /// 나가기·이름 저장 중 어느 줄이 돌고 있는지 가르는 키. 진행 중엔 다른 동작도 막는다.
  static const _leaveKey = 'leave';
  static const _editKey = 'edit';

  // 시안 세로 간격 (머리 > 줄 > 초대 > 그만두기)
  static const _headerInset = 8.0;
  static const _headingToCaptionGap = 8.0;
  static const _captionToRowsGap = 16.0;
  static const _rowGap = 8.0;
  static const _rowsToSectionGap = 40.0;
  static const _sectionLabelToCardGap = 12.0;
  static const _cardGap = 17.0;

  Future<void> _leave(String profileId, String profileName, List<Guardian> guardians) async {
    if (busy) return;
    // await 뒤에서 context 를 읽지 않도록 문구는 먼저 잡아 둔다.
    final l10n = context.l10n;
    // 목록에서 "나" 외에 다른 사람이 없으면 마지막 보호자다.
    final isLast = guardians.every((g) => g.me);

    final ok = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: l10n.guardiansLeaveConfirmTitle,
      // 무엇이 사라지고 무엇이 남는지 먼저 말한다 (되돌릴 수 없는 일 · 서버 명세 4-3).
      message: isLast
          ? l10n.guardiansLeaveConfirmMessageLast
          : l10n.guardiansLeaveConfirmMessageOthers,
      // 긴 안내가 단어 중간에서 꺾이지 않게 어절 단위로 줄바꿈한다.
      keepWordsInMessage: true,
      actions: [
        ElumDialogAction(label: l10n.commonCancel, value: false, tone: ElumDialogTone.neutral),
        ElumDialogAction(
          label: l10n.guardiansLeaveConfirmAction,
          value: true,
          tone: ElumDialogTone.danger,
        ),
      ],
    );
    if (ok != true || !mounted) return;

    // 나가기 요청과 뒤이은 세션 정리를 한 덩어리로 잠가, 화면을 떠나기 전까지 스피너가 돈다.
    final done = await runBusy(() async {
      final failure = await ref.read(guardiansControllerProvider).leave(profileId);
      // 이미 지워진 이룸이(404)는 나가려던 목적이 이루어진 것이다 — 정리만 한다.
      final alreadyGone = failure?.server?.code == ServerErrorCode.profileNotFound;
      if (failure != null && !alreadyGone) return (failure: failure, outcome: null);
      if (!mounted) return (failure: null, outcome: null);
      final outcome = await ref.read(profileSessionProvider.notifier).left(profileId);
      return (failure: null, outcome: outcome);
    }, key: _leaveKey);
    // 이미 진행 중이라 실행하지 않았다.
    if (done == null || !mounted) return;

    final failure = done.failure;
    if (failure != null) {
      await showFailure(
        context,
        failure,
        title: l10n.guardiansLeaveFailTitle,
        fallback: l10n.guardiansLeaveFailedFallback,
        fallbackCode: 'E-LEAVE',
      );
      // 서버가 "이 이룸이는 볼 수 없다"고 답했다면 목록이 옛것이다 — 다시 받는다.
      if (mounted) ref.invalidate(guardiansProvider(profileId));
      return;
    }

    final outcome = done.outcome;
    if (outcome == null) return;
    // 화면을 옮기기 전에 잡아 둔다 — 옮긴 뒤에는 이 화면의 context 가 없다.
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (outcome) {
      case LeftOutcome.none:
        // 이룸이가 하나도 없다 — 이룸이 등록(온보딩)으로 보낸다 (E29).
        context.go(Routes.onboardingName);
      case LeftOutcome.switched || LeftOutcome.stayed:
        context.go(Routes.guardian);
    }
    showElumToastOn(messenger, l10n.guardiansLeft(profileName));
  }

  Future<void> _editMe(String profileId, Guardian me) async {
    if (busy) return;
    final edit = await showGuardianEditSheet(context, me: me);
    if (edit == null || edit.isEmpty || !mounted) return;

    final attempt = await runBusy(
      () => ref.read(guardiansControllerProvider).updateMyGuardian(
        profileId,
        kind: edit.kind,
        displayName: edit.displayName,
      ),
      key: _editKey,
    );
    if (attempt == null || !mounted) return;

    if (!attempt.isOk) {
      await showFailure(
        context,
        attempt.failure,
        title: context.l10n.guardiansNameEditFailTitle,
        fallback: context.l10n.guardiansNameEditFailedFallback,
        fallbackCode: 'E-PPL-EDIT',
      );
      return;
    }
    ref.invalidate(guardiansProvider(profileId));
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final active = ref.watch(activeProfileProvider);
    final memberAsync = ref.watch(memberProvider).isLoading;

    // 다른 보호자의 이름 변경·합류·나가기가 푸시로 오지 않는다 — 화면이 떠 있는 동안 주기로 다시 받는다.
    return PeriodicRefresh(
      onRefresh: _refreshGuardians,
      child: ElumScaffold(
        onBack: context.popOrHome,
        isBackEnabled: !busy,
        title: context.l10n.guardiansTitle,
        backTop: 67,
        horizontalPadding: 16,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40.h),
              if (active == null)
                // 이룸이를 알아내는 중이거나 이룸이가 없다.
                memberAsync
                    ? const _Loading()
                    : _StateSlot(
                        child: ElumErrorView(
                          message: context.l10n.guardiansNoProfileMessage,
                          description: context.l10n.guardiansNoProfileDescription,
                          errorCode: 'E-PPL-NONE',
                          compact: true,
                        ),
                      )
              else
                ..._body(active.id, active.displayName),
              SizedBox(height: space.lg),
            ],
          ),
        ),
      ),
    );
  }

  /// 목록을 조용히 다시 받는다. 나가기·저장 중이거나 받는 중이면 건너뛴다 —
  /// 이미 떠난 이룸이를 조회해 404 를 받거나 요청이 겹치지 않게 한다.
  void _refreshGuardians() {
    final active = ref.read(activeProfileProvider);
    if (busy || active == null) return;
    final provider = guardiansProvider(active.id);
    if (ref.read(provider).isLoading) return;
    ref.invalidate(provider);
  }

  List<Widget> _body(String profileId, String profileName) {
    final async = ref.watch(guardiansProvider(profileId));
    final guardians = async.value;
    // 목록을 받았고 "나" 외에 아무도 없으면 혼자 돌보는 것
    final isAlone = guardians != null && guardians.isNotEmpty && guardians.every((g) => g.me);
    final hasGuardians = guardians != null && guardians.isNotEmpty;

    return [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _headerInset.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 몇 명인지 모르면(목록 전) 제목 없이 설명만
            if (guardians != null)
              KeptText(
                context.l10n.guardiansPeopleHeader(guardians.length),
                style: context.typo.peopleHeading.copyWith(color: context.colors.peopleTextPrimary),
              ),
            SizedBox(height: _headingToCaptionGap.h),
            KeptText(
              context.l10n.guardiansIntro,
              style: context.typo.peopleCaption.copyWith(color: context.colors.peopleTextSecondary),
            ),
          ],
        ),
      ),
      SizedBox(height: _captionToRowsGap.h),
      // 이미 받은 목록이 있으면 주기 갱신 실패(오프라인 등)로 목록을 오류 화면으로 바꾸지 않음
      if (async.hasError && guardians == null)
        _StateSlot(
          child: ElumErrorView.failure(
            async.error,
            fallback: context.l10n.guardiansLoadFailedFallback,
            fallbackCode: 'E-PPL',
            onRetry: () => ref.invalidate(guardiansProvider(profileId)),
            compact: true,
          ),
        )
      else if (guardians == null)
        const _Loading()
      else if (guardians.isEmpty)
        // 보호자가 한 명도 없는 이룸이는 서버에 있을 수 없음 (응답 형식이 달라진 것)
        _StateSlot(
          child: ElumErrorView(
            message: context.l10n.guardiansEmptyMessage,
            errorCode: 'E-PPL-EMPTY',
            compact: true,
          ),
        )
      else ...[
        for (final (index, g) in guardians.indexed) ...[
          if (index > 0) SizedBox(height: _rowGap.h),
          GuardianPersonRow(
            guardian: g,
            onRename: g.me && !busy ? () => _editMe(profileId, g) : null,
            isRenameLoading: g.me && isBusy(_editKey),
          ),
        ],
        // 내 줄만 있으면 비어 보임 (무엇을 하면 되는지 아래에 알림)
        if (isAlone) ...[
          SizedBox(height: _rowGap.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _headerInset.w),
            child: KeptText(
              context.l10n.guardiansAloneHint,
              style: context.typo.peopleCaption.copyWith(color: context.colors.peopleTextSecondary),
            ),
          ),
        ],
      ],
      SizedBox(height: _rowsToSectionGap.h),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: PeopleActionRow.defaultStartInset.w),
        child: Text(
          context.l10n.guardiansInviteHeader,
          style: context.typo.peopleSectionLabel.copyWith(color: context.colors.peopleTextPrimary),
        ),
      ),
      SizedBox(height: _sectionLabelToCardGap.h),
      PeopleActionCard(
        children: [
          PeopleActionRow(
            label: context.l10n.guardiansInviteAction,
            onTap: busy ? null : () => context.push(Routes.guardianInvite),
          ),
          PeopleActionRow(
            label: context.l10n.guardiansEnterCodeAction,
            onTap: busy ? null : () => context.push(Routes.inviteEnter),
          ),
        ],
      ),
      SizedBox(height: _cardGap.h),
      // 되돌릴 수 없는 줄은 맨 아래 따로 두고 위험색으로 칠함. 목록을 못 받았으면 몇 명인지
      // 모르므로 누를 수 없고, 혼자인지 모르므로 무엇이 사라지는지도 말하지 않음
      PeopleActionCard(
        children: [
          PeopleActionRow(
            label: context.l10n.guardiansLeaveAction,
            subtitle: hasGuardians
                ? (isAlone
                      ? context.l10n.guardiansLeaveHintAlone
                      : context.l10n.guardiansLeaveHintWithOthers)
                : null,
            isDestructive: true,
            isLoading: isBusy(_leaveKey),
            startInset: PeopleActionRow.compactStartInset,
            onTap: (busy || guardians == null || guardians.isEmpty)
                ? null
                : () => _leave(profileId, profileName, guardians),
          ),
        ],
      ),
    ];
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const _StateSlot(child: ElumStateBody.loading());
}

/// 목록 자리의 로딩·실패·빈 상태가 함께 쓰는 여백 — 바뀔 때 시작 위치가 같다.
class _StateSlot extends StatelessWidget {
  const _StateSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 24.h),
    child: child,
  );
}
