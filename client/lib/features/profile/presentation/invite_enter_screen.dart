import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/batchim.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/show_failure.dart';
import '../../link/domain/link_code.dart';
import '../../link/presentation/widgets/code_entry_field.dart';
import '../application/invite_inbox.dart';
import '../application/profile_session.dart';
import '../application/invite_enter_controller.dart';
import '../data/profile_repository.dart';
import '../domain/invite_problem.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/router/routes.dart';

/// 입력 아래에 보이는 안내의 종류. 문구가 아니라 종류를 들고 있다가 그릴 때 푼다 — 실패 순간에
/// 문구로 굳히면 언어가 바뀐 뒤에도 옛 언어로 남는다.
enum _InviteFault {
  /// 링크는 맞는데 코드를 못 쓰는 모양이다 (`E-INV-LINK`, 서버를 거치지 않는다).
  linkInvalid,

  /// 직접 친 코드의 모양이 틀렸다 (`E-INV-FORM`, 서버를 거치지 않는다).
  formInvalid,
  notFound,
  expired,
  tooManyAttempts,
  alreadyGuardian,
  forbiddenForElumi,
  invalidInput,
  offline,
  other,
}

class _InviteError {
  const _InviteError(this.fault, [this.failure]);

  final _InviteFault fault;

  /// 서버가 준 실패. 이유를 말해 줬으면 그 문구가 기본 문구를 이긴다 (#347).
  final AppFailure? failure;

  String message(AppLocalizations l10n) {
    String say(String fallback, String code) =>
        failure?.describe(fallback, code) ?? '$fallback ($code)';

    return switch (fault) {
      _InviteFault.linkInvalid => l10n.inviteEnterLinkInvalid,
      _InviteFault.formInvalid => l10n.inviteEnterFormInvalid,
      _InviteFault.notFound => say(l10n.inviteEnterNotFound, 'E-INV-404'),
      _InviteFault.expired => say(l10n.inviteEnterExpired, 'E-INV-410'),
      _InviteFault.tooManyAttempts => say(l10n.inviteEnterTooManyAttempts, 'E-INV-429'),
      _InviteFault.alreadyGuardian => say(l10n.inviteEnterAlreadyGuardian, 'E-INV-409'),
      _InviteFault.forbiddenForElumi => say(l10n.inviteEnterForbiddenForElumi, 'E-INV-403'),
      _InviteFault.invalidInput => say(l10n.inviteEnterInvalidInput, 'E-INV-400'),
      _InviteFault.offline => say(l10n.inviteEnterOffline, 'E-NET'),
      _InviteFault.other => say(l10n.inviteEnterOther, 'E-INV'),
    };
  }
}

/// 초대 코드 넣기 — 함께하는 보호자에게 받은 코드로 **그 이룸이에 합류**한다 (다중 보호자 #362).
///
/// > ⚠️ **임시 시안이다.** 디자인 시안이 없어 연결 암호 넣기(`LinkEnterScreen`)의 여섯 칸·
/// > 시스템 키보드·자동 제출·흔들림 모양을 그대로 빌렸다. 진입점도 시안이 정하지 않았다
/// > (이슈 #362 "정할 것") — 지금은 온보딩 이름 화면의 링크와 설정의 `함께하는 사람`에서 온다.
///
/// ## 새로 가입한 보호자 (E6)
///
/// 합류하면 이룸이 등록(온보딩)을 건너뛰고 **합류한 이룸이의 보호자 홈**으로 간다. 약관 동의는
/// 이 화면 앞에서 이미 받았다 — 동의 없이 들어오면 서버가 `CONSENT_REQUIRED` 로 막고, 그때는
/// 팝업으로 알린 뒤 동의 화면으로 보낸다. 가입 때 생긴 빈 이룸이는 서버가 지운다.
///
/// ## 실패 — 갈래마다 다음 동작이 다르다
///
/// | 갈래 | 입력 | 그 밖에 |
/// | --- | --- | --- |
/// | 없는·쓴 코드 / 만료 | 비운다 | 새 코드를 받으라고 말한다 |
/// | 이미 함께함 (자기 코드 포함) | 비운다 | 코드는 쓰이지 않았다 |
/// | 시도 한도 | **잠근다** | 더 쳐도 시도만 늘고 막힌다 |
/// | 인터넷 없음 | **남긴다** | `다시 시도` — 다시 칠 필요가 없다 |
/// | 약관 미동의 | — | 팝업 → 동의 화면 |
///
/// 문구는 서버가 준 것을 그대로 쓰고 **에러 코드를 함께 보인다** (제보를 받았을 때 추적).
/// 틀려도 붉게 칠하지 않는다 — 이 앱은 이룸이 휴대폰에도 깔린다.
///
/// ## 링크로 열렸을 때 (#365)
///
/// 보호자가 공유한 링크를 누르면 [InviteInbox](우편함)에 코드가 맡겨지고, 이 화면이 열리면서 꺼내 **칸에
/// 채운다.** 링크는 코드를 대신 전달하는 수단일 뿐이라 코드 흐름·합류 규칙은 그대로다.
///
/// - **자동으로 합류하지 않는다.** 여섯 자가 채워졌어도 서버에 보내지 않고 `함께하기` 를 기다린다 —
///   직접 칠 때는 여섯 자째가 곧 확인이지만, 링크는 누른 순간 합류하면 의도하지 않은 이룸이에 붙을 수 있다.
/// - 실패하면 확인 상태를 거두고 **직접 친 코드와 같은 갈래**로 안내한다 (입력을 비우고 새 코드를 받으라고 한다).
///   인터넷이 없을 때만 코드를 남겨 같은 버튼으로 다시 보낸다.
/// - 링크는 맞는데 코드를 못 쓰는 모양이면 빈 입력으로 열고 `E-INV-LINK` 로 안내한다.
/// - 이 화면이 이미 열려 있을 때 새 링크가 오면 우편함을 듣고 있다가 바로 채운다. 보내는 중이면 그 요청이 끝난 뒤.
class InviteEnterScreen extends ConsumerStatefulWidget {
  const InviteEnterScreen({super.key});

  @override
  ConsumerState<InviteEnterScreen> createState() => _InviteEnterScreenState();
}

class _InviteEnterScreenState extends ConsumerState<InviteEnterScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// 링크로 받은 코드를 맡겨 두는 곳 (#365).
  late final InviteInbox _inbox = ref.read(inviteInboxProvider);

  /// 링크로 받은 코드가 채워져 **확인을 기다린다.** 이때는 자동 제출도 키보드도 없다.
  bool _fromLink = false;

  /// 동의 화면으로 떠나는 중. 맡겨 둔 링크 코드를 이 화면이 다시 꺼내지 않게 한다.
  bool _leaving = false;

  /// 프로그램이 칸을 채우는 중. 사용자가 친 것으로 보고 자동 제출하지 않게 한다.
  bool _filling = false;

  _InviteError? _error;

  /// 틀린 횟수. 값이 바뀔 때마다 칸이 한 번 흔들린다.
  int _failCount = 0;

  /// 서버에 보내는 중. **같은 코드를 두 번 보내지 않는다** — 첫 요청이 합류시키면 두 번째는 409 다.
  bool _sending = false;

  /// 시도 한도(429)에 걸렸다. 더 입력해도 서버가 막고 시도만 늘어난다.
  bool _locked = false;

  /// 인터넷이 없어 못 보냈다. 입력을 남기고 다시 시도 버튼을 보인다.
  bool _offline = false;

  String get _typed => LinkCode.normalize(_controller.text);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _inbox.addListener(_onInbox);
    // 링크로 열렸다면 맡겨 둔 코드를 먼저 꺼내 채운다 (첫 프레임 전이라 setState 없이 값만 정한다).
    final pending = _inbox.take();
    if (pending != null) _apply(pending);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 확인을 기다리는 동안에는 키보드를 올리지 않는다 — 칠 것이 없다
      if (mounted && !_fromLink) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inbox.removeListener(_onInbox);
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 이 화면이 열려 있는 동안 새 링크가 왔다. 보내는 중이거나 잠겼으면 우편함에 그대로 둔다 —
  /// 보내던 요청이 끝난 뒤([_submit])에 이어 채운다.
  void _onInbox() {
    if (!mounted || _leaving || _sending || _locked) return;
    final pending = _inbox.take();
    if (pending == null) return;
    setState(() => _apply(pending));
    if (pending.code == null) _openKeyboard();
  }

  /// 링크로 받은 코드를 칸에 채운다. 코드를 못 쓰는 링크면 칸을 비우고 안내만 띄운다.
  ///
  /// 직접 치던 것은 새 링크가 대신한다 — 보호자가 코드를 다시 만들면 앞 코드는 서버에서 폐기된다.
  void _apply(PendingInvite pending) {
    final code = pending.code;
    _filling = true;
    _controller.text = code ?? '';
    _filling = false;
    _offline = false;
    if (code != null) {
      _fromLink = true;
      _error = null;
    } else {
      _fromLink = false;
      // 직접 친 코드의 형식 오류(E-INV-FORM)와 갈래를 나눠 제보를 받으면 어느 쪽인지 안다
      _error = const _InviteError(_InviteFault.linkInvalid);
      _failCount++;
    }
  }

  void _onChanged() {
    if (_filling || _sending || _locked) return;
    setState(() {});
    // 링크로 받은 코드는 확인 버튼을 기다린다 — 직접 고치려면 `다른 코드 넣기` 를 먼저 누른다.
    if (_fromLink) return;
    // 여섯 자를 채우면 바로 보낸다 — 확인 버튼을 따로 누르게 하지 않는다 (연결 암호와 같다).
    if (_typed.length == LinkCode.length) _submit();
  }

  Future<void> _submit() async {
    if (_sending || _locked) return;
    final code = _typed;
    if (!LinkCode.hasValidShape(code)) {
      // 우리가 만들 수 없는 모양은 서버에 보내지 않는다 — 계정당 시도 한도만 축낸다.
      _fail(const _InviteError(_InviteFault.formInvalid));
      return;
    }

    setState(() {
      _sending = true;
      _offline = false;
    });
    _focusNode.unfocus();
    final attempt = await ref
        .read(inviteEnterControllerProvider)
        .redeemInvite(code);
    if (!mounted) return;
    setState(() => _sending = false);

    if (attempt.isOk) {
      await _joined(attempt.value!);
      return;
    }
    await _handleFailure(attempt.failure!);
    // 보내는 동안 새 링크가 왔다면 이제 채운다
    if (mounted) _onInbox();
  }

  /// `다른 코드 넣기` — 채워진 코드를 거두고 직접 입력으로 바꾼다.
  void _useManualInput() {
    _filling = true;
    _controller.clear();
    _filling = false;
    setState(() {
      _fromLink = false;
      _error = null;
      _offline = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openKeyboard();
    });
  }

  Future<void> _joined(ProfileJoin join) async {
    // 합류한 이룸이를 고르고 이룸이별 값(이름·캐릭터·일과)을 맞춘다.
    await ref.read(profileSessionProvider.notifier).joined(join);
    if (!mounted) return;
    final name = join.profile.displayName;
    final joined = context.l10n.inviteJoined(name, batchimOf(name));
    // 화면을 옮기기 전에 잡아 둔다 — 옮긴 뒤에는 이 화면의 context 가 없다.
    final messenger = ScaffoldMessenger.maybeOf(context);
    context.go(Routes.guardian);
    showElumToastOn(messenger, joined);
  }

  Future<void> _handleFailure(AppFailure failure) async {
    switch (InviteProblem.of(failure)) {
      case InviteProblem.notFound:
        _fail(_InviteError(_InviteFault.notFound, failure));
      case InviteProblem.expired:
        _fail(_InviteError(_InviteFault.expired, failure));
      case InviteProblem.tooManyAttempts:
        // 잠근다 — 더 입력하면 시도만 늘고 같은 이유로 막힌다.
        _fail(_InviteError(_InviteFault.tooManyAttempts, failure), lock: true);
      case InviteProblem.alreadyGuardian:
        _fail(_InviteError(_InviteFault.alreadyGuardian, failure));
      case InviteProblem.forbiddenForElumi:
        _fail(_InviteError(_InviteFault.forbiddenForElumi, failure), lock: true);
      case InviteProblem.invalidInput:
        _fail(_InviteError(_InviteFault.invalidInput, failure));
      case InviteProblem.offline:
        // 입력을 남긴다 — 인터넷이 돌아오면 다시 칠 필요 없이 `다시 시도`만 누르면 된다.
        setState(() {
          _offline = true;
          _error = _InviteError(_InviteFault.offline, failure);
        });
      case InviteProblem.consentRequired:
        final linked = _fromLink ? _typed : null;
        await showFailure(
          context,
          failure,
          title: context.l10n.inviteEnterConsentFailTitle,
          fallback: context.l10n.inviteEnterConsentFallback,
          fallbackCode: 'E-INV-CONSENT',
        );
        if (!mounted) return;
        // 링크로 받은 코드는 동의를 마친 뒤에 이어 쓸 수 있게 다시 맡겨 둔다. 이 화면이 듣고 있으면
        // 제자리에서 다시 채우므로 떠나는 중이라고 표시해 꺼내지 않게 한다.
        if (linked != null && linked.isNotEmpty) {
          _leaving = true;
          _inbox.receive(linked);
        }
        context.go(Routes.consent);
      case InviteProblem.other:
        _fail(_InviteError(_InviteFault.other, failure));
    }
  }

  /// 실패 — 입력을 비우고 흔들어 알린다. 붉은 경고를 크게 쓰지 않는다.
  void _fail(_InviteError error, {bool lock = false}) {
    _controller.clear();
    setState(() {
      // 링크로 받은 코드도 실패하면 확인 상태를 거두고 직접 입력으로 돌아간다
      _fromLink = false;
      _error = error;
      _failCount++;
      _locked = lock;
    });
    if (lock) return;
    // 다음 프레임에 연다 — 같은 프레임에서 포커스를 잡으면 Android 가 키보드를 올리지 않았다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openKeyboard();
    });
  }

  /// 키보드를 연다 — 포커스가 이미 있어도 입력 연결을 새로 잡는다 (연결 암호 #428 과 같은 이유).
  void _openKeyboard() {
    if (_locked) return;
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
      return;
    }
    _focusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return ElumScaffold(
      onBack: _sending ? null : context.popOrHome,
      // 링크로 받은 코드는 사람이 눌러야 보낸다 (#365). **임시 시안** — 하단 버튼·보조 링크는 다른 입력
      // 화면(이름 입력 `다음` · `초대 코드가 있어요`)의 배치를 그대로 빌렸다.
      bottomButton: _fromLink
          ? ElumButton(label: context.l10n.inviteEnterJoinButton, onPressed: _sending ? null : _submit)
          : null,
      belowButton: _fromLink
          ? Center(
              child: AppPressable(
                onTap: _sending ? null : _useManualInput,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: space.xs.h),
                  child: Text(
                    context.l10n.inviteEnterManualLink,
                    style: context.typo.linkLater.copyWith(
                      color: colors.linkLaterLabel,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            )
          : null,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              title: context.l10n.inviteEnterTitle,
              description:
                  _error?.message(context.l10n) ??
                  (_fromLink
                      ? context.l10n.inviteEnterDescriptionFromLink
                      : context.l10n.inviteEnterDescriptionManual),
            ),
            SizedBox(height: space.lg),
            // 어디서 받는지 적어 준다. 받는 사람은 처음 보는 화면이다. 링크로 받았다면 이미 안다.
            if (!_fromLink)
              Container(
                padding: EdgeInsets.all(space.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(space.cardRadius.r),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.inviteEnterWhereFrom,
                      style: context.typo.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: space.sm),
                    Text(
                      context.l10n.inviteEnterWherePath,
                      style: context.typo.subtitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: space.sm),
                    Text(
                      context.l10n.inviteEnterWhereHow,
                      style: context.typo.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            if (!_fromLink) SizedBox(height: space.xl),
            CodeEntryField(
              controller: _controller,
              focusNode: _focusNode,
              value: _typed,
              semanticsLabel: _fromLink
                  ? context.l10n.inviteEnterSemanticsFromLink
                  : context.l10n.inviteEnterSemanticsInput,
              // 링크로 받은 코드는 칸을 눌러도 고쳐지지 않는다 — `다른 코드 넣기` 로 바꾼다
              onTap: _fromLink ? null : _openKeyboard,
              failCount: _failCount,
              hasError: _error != null,
              sending: _sending,
              enabled: !_locked && !_fromLink,
            ),
            // 링크로 받은 코드는 `함께하기` 가 다시 시도다 — 같은 일을 하는 버튼을 둘 두지 않는다
            if (_offline && !_sending && !_fromLink) ...[
              SizedBox(height: space.lg),
              Center(
                child: AppPressable(
                  onTap: _submit,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: space.md.w,
                      vertical: space.sm.h,
                    ),
                    child: Text(
                      context.l10n.commonRetry,
                      style: context.typo.linkLater.copyWith(
                        color: colors.linkLaterLabel,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
