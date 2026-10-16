import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../profile/application/profile_session.dart';
import '../application/issued_code_memory.dart';
import '../application/link_code_controller.dart';
import '../domain/link_code_link.dart';
import '../domain/link_status.dart';
import 'widgets/issued_code_actions.dart';
import 'widgets/issued_code_panel.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';

/// 연결 암호 만들기 — **보호자 휴대폰**.
///
/// 진입은 두 곳이고 **시안이 서로 다르다.**
///
/// | | 온보딩 (`732:5334`) | 설정 (`1027:4617`) |
/// | --- | --- | --- |
/// | 네비게이션 제목 | 없음 | `이룸이 휴대폰 연결` |
/// | 뒤로가기 y | 79 | **67** |
/// | 제목 y | 131 | **147** |
/// | 시작하기 | 있음 | **없음** |
/// | 나중에 할게요 | 있음 | 없음 |
/// | 링크로 보내기 | 있음(`시작하기` 위 보조 버튼) | 하단 버튼 |
/// | 코드 아래 | 복사하기 > `09:59 뒤에 코드가 바껴요` | `09:59` > 다시 만들기 |
///
/// 설정에서는 이미 앱 안이라 `시작하기`가 갈 곳이 없다 — 연결하면 팝업으로
/// 알리고 뒤로가기로 돌아간다. 시안도 그렇게 그려져 있다.
///
/// 이 화면의 주인공은 **여섯 글자**다. QR이 빠지면서 화면이 비었으므로 암호를 크게 키운다.
///
/// ## 상태 셋 (Figma 732:5334 · 732:5702 · 732:5850)
///
/// | | 암호 | 타이머 | 다시 만들기 | CTA |
/// | --- | --- | --- | --- | --- |
/// | 대기 | 보임 | `09:59` 빨강 | 있음 | 비활성 |
/// | 연결 성공 | 보임 | — | — | 팝업이 덮는다 |
/// | 연결됨 | 보임 | **없음** | **없음** | **활성** |
///
/// 연결되면 타이머와 다시 만들기가 사라진다 — **더 기다릴 이유가 없어서다.**
/// `나중에 할게요`는 세 상태 모두에 남는다 (시안 `732:5850`).
///
/// ## 온보딩 진입의 코드 갱신
///
/// 온보딩 시안은 `다시 만들기` 칩이 없고 `뒤에 코드가 바껴요`라고 말한다. 만료되면 **자동으로 새 코드**를 받아
/// 타이머를 다시 돌린다. 새로 받지 못하면(실패) 다시 만들기 칩이 대신 나온다.
///
/// ## 설정 진입의 전하기 · 다시 들어오기
///
/// 설정에서 들어온 화면에는 초대 코드 화면과 같은 하단 버튼(`링크로 보내기` · `코드 복사하기`)과 안내가 있다.
/// 나갔다 들어와도 서버에 아직 살아 있는 코드면 같은 코드를 보여 준다 ([IssuedCodeMemory]) —
/// 새로 만드는 것은 `코드 다시 만들기`를 눌렀을 때와 기억한 코드를 못 쓸 때뿐이다.
class LinkCodeScreen extends ConsumerStatefulWidget {
  const LinkCodeScreen({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  ConsumerState<LinkCodeScreen> createState() => _LinkCodeScreenState();
}

class _LinkCodeScreenState extends ConsumerState<LinkCodeScreen> {
  IssuedLinkCode? _issued;
  bool _loading = true;

  // 문구가 아니라 실패 자체를 들고 있다가 그릴 때 푼다 — 실패 순간에 문구로 굳히면
  // 언어가 바뀐 뒤에도 옛 언어로 남는다.
  AppFailure? _issueFailure;

  /// 남은 시간을 1초마다 다시 그린다. 시안이 `09:59`를 초까지 보여준다.
  Timer? _ticker;

  /// 연결됐는지 주기적으로 확인한다. 보호자가 이 화면을 보고 있는 동안
  /// 이룸이 휴대폰이 암호를 넣으면 **여기서 바로 알아야** 한다.
  Timer? _poller;

  bool _linked = false;

  /// 성공 팝업을 두 번 띄우지 않는다. 폴링이 한 박자 늦게 또 돌 수 있다.
  bool _celebrated = false;

  /// 설정 진입 시안(`1027:4617`)의 뒤로가기 y와 제목 y.
  /// 설정 묶음은 전부 67/147 이다 — 온보딩 계열(79/131)과 12·16씩 다르다.
  static const _settingsBackTop = 67.0;
  static const _settingsTitleY = 147.0;

  /// 온보딩 시안의 `링크로 보내기`(y=593~659)와 `시작하기`(y=675) 사이 (Figma 1532:6801).
  static const _onboardingButtonGap = 16.0;

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

  /// 이 화면이 열릴 때 이미 붙어 있던 휴대폰들. 새로 붙은 것만 `연결 성공`이다.
  /// 다시 만들기를 눌러도 처음 기준을 유지한다 — 그사이 붙은 것은 새로 붙은 것이다.
  Set<String>? _knownLinkIds;

  /// 기억한 코드의 열쇠. 이룸이마다 따로 둔다.
  late final String _memoryKey = IssuedCodeMemory.linkKey(
    ref.read(profileSessionProvider).selectedId,
  );

  /// [force] 가 true 면 기억한 코드를 쓰지 않고 새로 발급한다 (`코드 다시 만들기`).
  /// [isSilent] 가 true 면 스피너를 띄우지 않는다 (만료 자동 갱신 - 화면이 깜빡이지 않게).
  Future<void> _issue({bool force = false, bool isSilent = false}) async {
    setState(() {
      _loading = !isSilent;
      _issueFailure = null;
    });
    final memory = ref.read(issuedCodeMemoryProvider);

    if (!force) {
      LinkStatus? status;
      // 서버가 아는 내 미사용 암호의 만료와 같으면 같은 암호다. 이때 받은 목록이 곧 연결 기준이 된다.
      final reused = await memory.recallLive(_memoryKey, () async {
        final r = await ref.read(linkCodeControllerProvider).statusResult();
        if (!r.isOk) throw r.failure!;
        status = r.value;
        return r.value!.pendingExpiresAt;
      });
      if (!mounted) return;
      if (reused != null) {
        _knownLinkIds ??= status?.devices.map((d) => d.linkId).toSet();
        setState(() {
          _issued = reused;
          _loading = false;
        });
        _startTimers();
        return;
      }
    }
    // 기준은 암호를 만드는 것과 함께 잡는다 — 새 암호는 아직 쓰이지 않았으니 목록에 끼지 않는다.
    final (attempt, before) = await ref
        .read(linkCodeControllerProvider)
        .issue(withBaseline: _knownLinkIds == null);
    if (before != null && before.isOk) {
      _knownLinkIds ??= before.value!.devices.map((d) => d.linkId).toSet();
    }
    if (!mounted) return;

    if (!attempt.isOk) {
      setState(() {
        _loading = false;
        // 서버가 이유를 알려줬으면 그 문구를 그대로 쓴다 — 그릴 때 푼다.
        _issueFailure = attempt.failure;
      });
      return;
    }

    memory.remember(_memoryKey, attempt.value!);
    setState(() {
      _issued = attempt.value;
      _loading = false;
    });
    _startTimers();
  }

  void _startTimers() {
    _ticker?.cancel();
    _poller?.cancel();
    // 남은 시간을 초까지 보여주므로 1초마다 다시 그린다. 만료되면 멈춘다.
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final isExpired = _issued?.isExpired ?? true;
      if (isExpired) t.cancel();
      setState(() {});
      // 온보딩은 만료되면 새 코드를 자동으로 받는다 (실패하면 다시 만들기 칩이 대신 나온다)
      if (isExpired && widget.fromOnboarding && !_linked) _issue(force: true, isSilent: true);
    });
    // 3초는 서버에 부담이 크지 않으면서 사람이 기다린다고 느끼지 않는 간격이다.
    _poller = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (!mounted) return t.cancel();
      final attempt = await ref.read(linkCodeControllerProvider).statusResult();
      if (!mounted) return;
      // 못 물었으면 이번 박자는 건너뛴다 — 실패를 `연결 없음`으로 읽으면 안 된다.
      if (!attempt.isOk) return;
      final ids = attempt.value!.devices.map((d) => d.linkId).toSet();
      // **이 화면이 열린 뒤 새로 붙은 휴대폰만** 성공으로 알린다. 이미 연결된 보호자가
      // 새 암호를 만들러 들어오면 기존 연결을 방금 성공한 것처럼 팝업을 띄우게 된다. 열 때 기준을 못
      // 잡았으면(첫 조회 실패) 처음 성공한 응답을 기준으로 삼는다 — 틀리게 알리는 것보다 낫다.
      final known = _knownLinkIds ??= ids;
      if (ids.difference(known).isNotEmpty) {
        t.cancel();
        _ticker?.cancel();
        setState(() => _linked = true);
        _celebrate();
      }
    });
  }

  /// 연결 성공 팝업. 화면 밖으로 넘어가지 않고 **이 자리에서** 알린다.
  ///
  /// 팝업을 닫아도 화면에 머문다 — 연결됨 상태를 눈으로 확인하고 `시작하기`를
  /// 누르는 것이 시안의 흐름이다.
  Future<void> _celebrate() async {
    if (_celebrated) return;
    _celebrated = true;
    // 암호가 쓰였다 — 기억해 둔 암호는 더 보여 줄 수 없다.
    ref.read(issuedCodeMemoryProvider).forget(_memoryKey);
    await showElumDialog<void>(
      context: context,
      icon: ElumDialogIcon.success,
      title: context.l10n.linkCodeSuccessTitle,
    );
  }

  void _goHome() => context.go(Routes.guardian);

  /// 이룸이 이름. 비어 있으면 `이룸이`로 대신한다 — 온보딩을 건너뛰고 설정에서
  /// 바로 들어오면 이름이 없을 수 있다. `의`는 받침과 무관해 그냥 붙는다.
  String get _elumiName {
    final name = ref.watch(onboardingProvider).childNickname.trim();
    return name.isEmpty ? context.l10n.commonElumiName : name;
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;
    final issued = _issued;
    // 설정에서 들어온 화면은 머리와 하단이 통째로 다르다 (클래스 주석의 표).
    final fromSettings = !widget.fromOnboarding;

    return ElumScaffold(
      onBack: context.popOrHome,
      title: fromSettings ? context.l10n.linkCodeSettingsTitle : null,
      backTop: fromSettings ? _settingsBackTop : null,
      // 온보딩 시안은 연결되기 전에도 버튼을 **보여주되 누를 수 없게** 둔다
      // (732:5334) — 다음 할 일을 알려주는 이정표라 자리를 비우지 않는다.
      // 설정 시안(`1027:4617`)에는 버튼 자체가 없다.
      bottomButton: fromSettings
          ? (issued != null && _issueFailure == null && !_loading && !_linked
                ? IssuedCodeActions(
                    issued: issued,
                    shareMessage: (i) =>
                        LinkCodeLink.shareMessage(i.code, validFor: i.remaining()),
                    shareFailCode: 'E-LINK-SHARE',
                  )
                : null)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 연결되면 코드는 이미 쓰였다 - 더 보낼 수 없다
                IssuedCodeShareButton(
                  issued: _linked || _loading || _issueFailure != null ? null : issued,
                  shareMessage: (i) =>
                      LinkCodeLink.shareMessage(i.code, validFor: i.remaining()),
                  shareFailCode: 'E-LINK-SHARE',
                  isSecondary: true,
                ),
                SizedBox(height: _onboardingButtonGap.h),
                ElumButton(
                  label: context.l10n.linkCodeStartButton,
                  onPressed: _linked ? _goHome : null,
                ),
              ],
            ),
      // `나중에 할게요`는 CTA 아래에 붙는다 (시안 y=765).
      //
      // **연결된 뒤에도 남는다** — 시안 `732:5850`이 그렇게 그려져 있다.
      // 누르면 `시작하기`와 같은 곳으로 가므로 숨겨 봐야 얻는 것이 없다.
      //
      // **높이를 못 박지 않는다.** 16 으로 고정하면 글꼴을 키울 때 글자 아래가 잘리고
      // 경고도 안 난다. 글자 높이가 곧 자리이며 글꼴 1.0 에서는 시안 자리(765)와 같다.
      // 누름 영역은 옆으로만 넓힌다 — 위아래로 넓히면 CTA 를 밀어 올린다.
      belowButton: widget.fromOnboarding
          ? Center(
              child: AppPressable(
                onTap: _goHome,
                child: Padding(
                  // 옆 여백은 전과 같은 8 — 바꾸면 글자가 반 픽셀 옮겨 골든이 흔들린다.
                  padding: EdgeInsets.symmetric(horizontal: space.xs.h),
                  child: Text(
                    context.l10n.linkCodeLater,
                    style: context.typo.linkLater.copyWith(
                      color: colors.linkLaterLabel,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            )
          : null,
      // 글꼴을 키우면(2.0) 제목 두 줄·설명·암호·타이머·칩이 한 화면을 넘는다.
      // 고정 높이 칸에 두면 아래가 넘쳐 잘리므로 스크롤로 끝까지 볼 수 있게 한다
      // 글꼴 1.0 에서는 다 들어와 움직이지 않는다.
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              hasBackButton: true,
              // 설정 시안은 제목이 147에서 시작한다 — 뒤로가기 줄에 제목이 함께
              // 서면서 머리가 107에서 끝나기 때문이다.
              titleY: fromSettings ? _settingsTitleY : null,
              title: context.l10n.linkCodeAskTitle(_elumiName),
              // 서버가 이유를 알려줬으면 그 문구가 기본 문구를 이긴다.
              description:
                  _issueFailure?.describe(
                    context.l10n.linkCodeIssueFailedFallback,
                    'E-LINK-NEW',
                  ) ??
                  context.l10n.linkCodeEnterHint(_elumiName),
            ),
            IssuedCodePanel(
              loading: _loading,
              issued: issued,
              expiredLabel: context.l10n.linkCodeExpired,
              // 연결되면 타이머도 `다시 만들기`도 사라진다 — 더 기다릴 이유가 없다.
              showStatus: !_linked,
              onRetry: () => _issue(force: true),
              // 온보딩 시안: 복사하기 > `09:59 뒤에 코드가 바껴요` (다시 만들기는 만료 뒤 실패했을 때만)
              onCopy: widget.fromOnboarding
                  ? () => copyIssuedCode(context, issued)
                  : null,
              timerSuffix: widget.fromOnboarding
                  ? context.l10n.linkCodeChangesAfter
                  : null,
              footer: fromSettings
                  ? [
                      SizedBox(height: IssuedCodePanel.timerToRetry.h),
                      // 되돌릴 수 없는 일(앞 암호가 쓸 수 없게 된다)을 먼저 말한다.
                      Text(
                        context.l10n.inviteCodeRetryNote,
                        textAlign: TextAlign.center,
                        style: context.typo.body.paragraph.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: IssuedCodePanel.timerToRetry.h),
                      Text(
                        context.l10n.linkCodePhoneNote,
                        textAlign: TextAlign.center,
                        style: context.typo.bodySmall.paragraph.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ]
                  : const [],
            ),
          ],
        ),
      ),
    );
  }
}
