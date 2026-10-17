import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/batchim.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../link/domain/link_status.dart';
import '../../link/application/issued_code_memory.dart';
import '../../link/presentation/widgets/issued_code_actions.dart';
import '../../link/presentation/widgets/issued_code_panel.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../application/guardians_controller.dart';
import '../application/invite_code_controller.dart';
import '../application/profile_session.dart';
import '../domain/invite_link.dart';
import '../../../core/router/pop_or_home.dart';
import '../../member/application/member_providers.dart';

/// 초대 코드 만들기: 연결된 보호자가 **함께 돌볼 보호자**를 부른다 (Figma 1579:8206).
///
/// 이룸이 **휴대폰**을 붙이는 것은 `연결 암호`, 다른 **보호자**를 붙이는 것은 `초대 코드`다.
/// 두 갈래가 같은 말이면 보호자가 어느 쪽을 만드는지 헷갈린다.
/// 배치는 연결 암호 화면의 설정 진입(`1532:6671`)과 같다: 코드 > `코드 복사하기` > `09:59 뒤에 코드가 바껴요`,
/// 하단에 `링크로 보내기` 하나.
///
/// ## 상태
///
/// | | 코드 | 복사하기 · 타이머 |
/// | --- | --- | --- |
/// | 만드는 중 | — | — |
/// | 대기 | 보임 | 있음 |
/// | 새로 못 받음 | — | 서버가 다시 해도 같은 이유면 다시 시도 없음 |
///
/// 시간이 다 되면 `만료`라 말하지 않고, 새 코드를 조용히 받아 타이머를 다시 돌린다.
/// 이전에 만든 미사용 코드는 서버가 폐기한다 (E9): 다시 만들면 앞 코드는 쓸 수 없다.
///
/// ## 링크로 보내기
///
/// 여섯 글자를 불러주는 대신 **링크 하나를 메신저로 보낸다.** 받은 사람이 누르면 앱이 열리고 초대 코드
/// 넣기 화면에 코드가 채워진다. 보낼 때마다 지금 화면에 보이는 코드로 링크를 만든다.
///
/// ## 다시 들어와도 같은 코드
///
/// 서버는 코드 원문을 모른다. 그래서 받은 코드와 만료를 앱이 메모리([IssuedCodeMemory])에 기억해 두었다가,
/// 다시 들어오면 서버에 아직 살아 있는지만 묻고 그대로 보여 준다. 확인에 실패하거나 어긋나면 새로 발급한다.
class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  IssuedLinkCode? _issued;
  AppFailure? _failure;
  bool _loading = true;

  /// 시간이 다 된 코드를 새 코드로 바꾸는 중. 스피너 없이 옛 코드를 그대로 둔다.
  bool _isRenewing = false;

  /// 연결된 이룸이가 없어 부를 곳이 없다 (E29). 서버 실패가 아니라 앱이 아는 상태다.
  bool _noProfile = false;

  /// 코드를 만들 이룸이 호칭. 서버 조회가 끝나야 알 수 있어 [_issue] 가 정한다.
  /// 비어 있으면 그릴 때 공용 호칭(`이룸이`)으로 푼다 — 문구를 상태에 굳히지 않는다.
  String? _name;

  Timer? _ticker;

  /// 코드를 받은 사람이 합류했는지 주기적으로 묻는다. 보낸 사람은 이 화면을 보고 있어야 바로 안다.
  Timer? _poller;

  /// 이 화면을 연 뒤 이미 함께하던 사람들. 여기에 없는 사람이 생기면 새로 합류한 것이다.
  /// 처음 조회가 실패하면 null 이고, 처음 성공한 응답이 기준이 된다.
  Set<String>? _knownGuardianIds;

  /// 합류 팝업을 두 번 띄우지 않는다. 폴링이 한 박자 늦게 또 돌 수 있다.
  bool _celebrated = false;

  /// 폴링 요청이 아직 돌고 있다. 응답이 3초보다 늦을 때 요청이 쌓이지 않게 한다.
  bool _polling = false;

  /// 설정 묶음 시안의 머리: 뒤로가기 y=67, 제목 y=147.
  static const _settingsBackTop = 67.0;
  static const _settingsTitleY = 147.0;

  @override
  void initState() {
    super.initState();
    _issue();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  /// 지금 화면이 보여 주는 코드의 기억 열쇠. 이룸이를 정한 뒤에만 있다.
  String? _memoryKey;

  /// [force] 가 true 면 기억한 코드를 쓰지 않고 새로 발급한다 (`코드 다시 만들기`).
  /// [isSilent] 가 true 면 스피너를 띄우지 않는다 (시간이 다 된 코드의 자동 교체 - 화면이 깜빡이지 않게).
  Future<void> _issue({bool force = false, bool isSilent = false}) async {
    setState(() {
      _loading = !isSilent;
      _isRenewing = isSilent;
      _failure = null;
      _noProfile = false;
    });

    // 이룸이는 회원 정보가 알려 준다. 조회가 실패해도 고른 이룸이 id 가 있으면 계속한다.
    final member = await ref.read(memberProvider.future);
    if (!mounted) return;
    final active = pickActiveProfile(
      member,
      ref.read(profileSessionProvider).selectedId,
    );
    if (active == null) {
      setState(() {
        _loading = false;
        _isRenewing = false;
        _noProfile = true;
      });
      return;
    }
    final local = ref.read(onboardingProvider).childNickname.trim();
    _name = active.nickname?.trim().isNotEmpty == true
        ? active.displayName
        : (local.isEmpty ? null : local);

    final memory = ref.read(issuedCodeMemoryProvider);
    final key = _memoryKey = IssuedCodeMemory.inviteKey(active.id);
    final controller = ref.read(inviteCodeControllerProvider);

    // 나갔다 들어와도 코드를 유지한다 — 서버에 아직 살아 있는지만 확인한다.
    final reused = force
        ? null
        : await memory.recallLive(key, () async {
            final pending = await controller.pendingExpiry(active.id);
            if (!pending.isOk) throw pending.failure!;
            return pending.value;
          });
    if (!mounted) return;
    if (reused != null) {
      setState(() {
        _issued = reused;
        _loading = false;
        _isRenewing = false;
      });
      _startTicker();
      _startPoller(active.id);
      return;
    }

    final attempt = await controller.issueInvite(active.id);
    if (!mounted) return;

    if (!attempt.isOk) {
      setState(() {
        _loading = false;
        _isRenewing = false;
        _failure = attempt.failure;
      });
      return;
    }
    memory.remember(key, attempt.value!);
    setState(() {
      _issued = attempt.value;
      _loading = false;
      _isRenewing = false;
    });
    _startTicker();
    _startPoller(active.id);
  }

  /// 3초마다 함께하는 사람을 받아 새로 생긴 사람이 있으면 합류를 알린다. 못 받은 박자는 건너뛴다 —
  /// 실패를 `아무도 없음`으로 읽지 않는다. 코드가 만료되면 더 기다릴 이유가 없어 멈춘다.
  void _startPoller(String profileId) {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (!mounted || (_issued?.isExpired ?? true)) return t.cancel();
      if (_polling || _celebrated) return;
      _polling = true;
      try {
        final attempt = await ref.read(guardiansControllerProvider).listGuardians(profileId);
        if (!mounted || !attempt.isOk) return;
        final guardians = attempt.value ?? const [];
        // 열 때 기준을 못 잡았으면 처음 성공한 응답을 기준으로 삼는다 — 틀리게 알리는 것보다 낫다.
        final known = _knownGuardianIds;
        if (known == null) {
          _knownGuardianIds = guardians.map((g) => g.id).toSet();
          return;
        }
        final joined = guardians.where((g) => !known.contains(g.id)).toList();
        if (joined.isEmpty) return;
        t.cancel();
        _ticker?.cancel();
        await _celebrate(joined.first.label);
      } catch (_) {
        // 폴링 실패는 화면을 깨지 않는다 — 다음 박자에 다시 묻는다.
      } finally {
        _polling = false;
      }
    });
    // 기준은 코드를 만들 때 잡는다 — 코드를 쓰기 전이라 합류자가 목록에 끼지 않는다.
    unawaited(_captureBaseline(profileId));
  }

  Future<void> _captureBaseline(String profileId) async {
    try {
      final attempt = await ref.read(guardiansControllerProvider).listGuardians(profileId);
      if (!mounted || !attempt.isOk) return;
      _knownGuardianIds ??= (attempt.value ?? const []).map((g) => g.id).toSet();
    } catch (_) {
      // 기준을 못 잡으면 첫 폴링 응답이 대신한다.
    }
  }

  /// 합류 팝업. 코드는 이미 쓰였으므로 확인하면 이전 화면으로 돌아간다.
  Future<void> _celebrate(String guestName) async {
    if (_celebrated || !mounted) return;
    _celebrated = true;
    // 코드가 쓰였다 — 기억해 둔 코드는 더 보여 줄 수 없다.
    final key = _memoryKey;
    if (key != null) ref.read(issuedCodeMemoryProvider).forget(key);
    await showElumDialog<void>(
      context: context,
      icon: ElumDialogIcon.success,
      title: context.l10n.inviteCodeGuestJoinedTitle(guestName),
    );
    if (mounted) context.popOrHome();
  }

  /// 남은 시간을 초까지 보여 주므로 1초마다 다시 그린다. 시간이 다 되면 멈추고 새 코드로 바꾼다.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final isExpired = _issued?.isExpired ?? true;
      if (isExpired) t.cancel();
      setState(() {});
      // 새 코드를 조용히 받는다 (실패하면 에러 화면과 다시 시도가 대신 나온다)
      if (isExpired && !_celebrated) _issue(force: true, isSilent: true);
    });
  }

  /// 다시 해도 같은 이유로 막히는 실패인가. 그때는 다시 시도 버튼을 두지 않는다.
  bool get _retryable {
    final f = _failure;
    if (f == null) return false;
    if (f.isUnreachable) return true;
    final status = f.server?.statusCode;
    // 연결 안 됨·이룸이 휴대폰(403)은 몇 번을 해도 같다. 시도 한도(429)·서버 오류는 시간이 지나면 풀린다.
    return status != 403;
  }

  @override
  Widget build(BuildContext context) {
    final issued = _issued;
    final failure = _failure;
    final name = _name ?? context.l10n.commonElumiName;

    return ElumScaffold(
      onBack: context.popOrHome,
      title: context.l10n.inviteCodeTitle,
      backTop: _settingsBackTop,
      // 만들지 못했거나 이룸이가 없으면 보낼 코드가 없어 꺼진다
      bottomButton: IssuedCodeShareButton(
        issued: failure == null && !_loading && !_noProfile ? issued : null,
        shareMessage: (i) => InviteLink.shareMessage(i.code, validFor: i.remaining()),
        shareFailCode: 'E-INV-SHARE',
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              titleY: _settingsTitleY,
              title: context.l10n.inviteCodeHeaderTitle,
              description: context.l10n.inviteCodeAsk(name, batchimOf(name)),
            ),
            IssuedCodePanel(
              loading: _loading,
              issued: issued,
              isRenewing: _isRenewing,
              onRetry: () => _issue(force: true),
              onCopy: () => copyIssuedCode(context, issued),
              replacement: _noProfile
                  // 이룸이가 없으면 다시 해도 같다 — 버튼 없이 이유와 코드만 보여 준다.
                  ? ElumErrorView(
                      message: context.l10n.inviteCodeNoProfileMessage,
                      description: context.l10n.inviteCodeNoProfileDescription,
                      errorCode: 'E-INV-NONE',
                    )
                  : failure != null
                  ? ElumErrorView.failure(
                      failure,
                      fallback: context.l10n.inviteCodeIssueFailedFallback,
                      fallbackCode: 'E-INV-NEW',
                      onRetry: _retryable ? _issue : null,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
