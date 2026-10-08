import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/batchim.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/show_failure.dart';
import '../../link/domain/link_status.dart';
import '../../link/presentation/widgets/issued_code_panel.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../application/invite_code_controller.dart';
import '../application/invite_sharer.dart';
import '../application/profile_session.dart';
import '../domain/invite_link.dart';
import '../../../core/router/pop_or_home.dart';
import '../../member/application/member_providers.dart';

/// 초대 코드 만들기 — 연결된 보호자가 **함께 돌볼 보호자**를 부른다 (다중 보호자 #362).
///
/// > ⚠️ **임시 시안이다.** 디자인 시안이 없어 연결 암호 만들기(`LinkCodeScreen`)의 설정 진입
/// > 모양(제목 줄·코드 3-3·`MM:SS`·다시 만들기 칩)을 그대로 빌렸다. 시안이 나오면 바꾼다.
///
/// ## 연결 암호와 말을 섞지 않는다
///
/// 이룸이 **휴대폰**을 붙이는 것은 `연결 암호`, 다른 **보호자**를 붙이는 것은 `초대 코드`다.
/// 2026-09-18 합의(#228)의 `코드` 예외는 그 온보딩 시안에만 적용되므로 여기서는 `초대 코드`로
/// 구분한다 — 두 갈래가 같은 말이면 보호자가 어느 쪽을 만드는지 헷갈린다.
///
/// ## 상태
///
/// | | 코드 | 타이머 | 다시 만들기 |
/// | --- | --- | --- | --- |
/// | 만드는 중 | — | — | — |
/// | 대기 | 보임 | `09:59` | 있음 |
/// | 만료 | 흐리게 | `만료됐어요` | 있음 |
/// | 실패 | — | — | 서버가 다시 해도 같은 이유면 없음 |
///
/// 이전에 만든 미사용 코드는 서버가 폐기한다 (E9) — 그래서 다시 만들면 앞 코드를 쓸 수 없다고
/// 먼저 알린다 (되돌릴 수 없는 일은 먼저 말한다).
///
/// ## 링크로 보내기 (#365)
///
/// 여섯 글자를 불러주는 대신 **링크 하나를 메신저로 보낸다.** 받은 사람이 누르면 앱이 열리고 초대 코드
/// 넣기 화면에 코드가 채워진다 — 링크는 코드를 대신 전달하는 수단일 뿐이다. 공유 문구에는 남은 시간
/// (10분)과 링크가 열리지 않을 때 직접 넣을 코드가 들어간다. **임시 시안** — 하단 버튼 자리는 다른
/// 화면의 `다음` 버튼을 빌렸다.
///
/// 만료된 코드는 보내지 않는다 (버튼이 꺼진다). 다시 만들면 앞 코드가 폐기되므로 **보낼 때마다 지금 화면에
/// 보이는 코드**로 링크를 만든다.
class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  IssuedLinkCode? _issued;
  AppFailure? _failure;
  bool _loading = true;

  /// 연결된 이룸이가 없어 부를 곳이 없다 (E29). 서버 실패가 아니라 앱이 아는 상태다.
  bool _noProfile = false;

  /// 코드를 만들 이룸이 호칭. 서버 조회가 끝나야 알 수 있어 [_issue] 가 정한다.
  /// 비어 있으면 그릴 때 공용 호칭(`이룸이`)으로 푼다 — 문구를 상태에 굳히지 않는다.
  String? _name;

  Timer? _ticker;

  /// 설정 진입 시안(`1027:4617`)과 같은 머리 — 뒤로가기 y=67, 제목 y=147.
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
    super.dispose();
  }

  Future<void> _issue() async {
    setState(() {
      _loading = true;
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
        _noProfile = true;
      });
      return;
    }
    final local = ref.read(onboardingProvider).childNickname.trim();
    _name = active.nickname?.trim().isNotEmpty == true
        ? active.displayName
        : (local.isEmpty ? null : local);

    final attempt = await ref.read(inviteCodeControllerProvider).issueInvite(active.id);
    if (!mounted) return;

    if (!attempt.isOk) {
      setState(() {
        _loading = false;
        _failure = attempt.failure;
      });
      return;
    }
    setState(() {
      _issued = attempt.value;
      _loading = false;
    });
    _startTicker();
  }

  /// 남은 시간을 초까지 보여 주므로 1초마다 다시 그린다. 만료되면 멈춘다.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_issued?.isExpired ?? true) t.cancel();
      setState(() {});
    });
  }

  /// 공유 시트로 링크를 보낸다. 시트를 못 열면 팝업으로 알린다 — 코드는 화면에 그대로 있어 불러줄 수 있다.
  Future<void> _share() async {
    final issued = _issued;
    // 만료됐거나 아직 없다면 보내지 않는다 — 받은 사람이 못 쓰는 코드를 눌러 서버에서 되돌려 받게 된다
    if (issued == null || issued.isExpired) return;
    try {
      await ref.read(inviteSharerProvider)(
        InviteLink.shareMessage(issued.code, validFor: issued.remaining()),
      );
    } catch (e) {
      // 코드는 로그에 남기지 않는다 — 예외만 넘긴다
      if (!mounted) return;
      await showFailure(
        context,
        e,
        title: context.l10n.inviteCodeShareFailTitle,
        fallback: context.l10n.inviteCodeShareFailFallback,
        fallbackCode: 'E-INV-SHARE',
      );
    }
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
    final colors = context.colors;
    final issued = _issued;
    final failure = _failure;
    final name = _name ?? context.l10n.commonElumiName;

    return ElumScaffold(
      onBack: context.popOrHome,
      title: context.l10n.inviteCodeTitle,
      backTop: _settingsBackTop,
      // 코드가 있을 때만 — 만들지 못했거나 이룸이가 없으면 보낼 것이 없다 (임시 시안)
      bottomButton: issued != null && failure == null && !_loading && !_noProfile
          ? ElumButton(
              label: context.l10n.inviteCodeShareButton,
              onPressed: issued.isExpired ? null : _share,
            )
          : null,
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
              expiredLabel: context.l10n.inviteCodeExpired,
              retryLabel: context.l10n.inviteCodeRetryChip,
              onRetry: _issue,
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
              footer: [
                SizedBox(height: IssuedCodePanel.timerToRetry.h),
                // 되돌릴 수 없는 일(앞 코드가 쓸 수 없게 된다)을 먼저 말한다. 한 줄이다.
                Text(
                  context.l10n.inviteCodeRetryNote,
                  textAlign: TextAlign.center,
                  style: context.typo.body.copyWith(color: colors.textSecondary),
                ),
                SizedBox(height: IssuedCodePanel.timerToRetry.h),
                // 초대 코드는 보호자용이다. 이룸이가 쓰는 휴대폰은 따로 붙인다.
                Text(
                  context.l10n.inviteCodeElumiPhoneNote,
                  textAlign: TextAlign.center,
                  style: context.typo.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
