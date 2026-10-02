import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_shake.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../auth/data/auth_repository.dart';
import '../data/device_link_repository.dart';
import '../domain/link_code.dart';
import 'widgets/code_boxes.dart';
import '../../../core/router/pop_or_home.dart';

/// 연결 실패의 종류. 문구가 아니라 종류를 들고 있다가 그릴 때 푼다 — 실패 순간에 문구로
/// 굳히면 언어가 바뀐 뒤에도 옛 언어로 남는다.
enum _EnterFault { wrongCode, expired, tooManyAttempts, offline, failed }

class _EnterError {
  const _EnterError(this.fault, [this.failure]);

  final _EnterFault fault;

  /// 서버가 준 실패. 이유를 말해 줬으면 그 문구가 기본 문구를 이긴다.
  final AppFailure? failure;

  String message(AppLocalizations l10n) {
    // 서버가 이유를 알려줬으면 그 문구가 기본 문구를 이긴다.
    String say(String fallback, String code) =>
        failure?.describe(fallback, code) ?? '$fallback ($code)';

    return switch (fault) {
      _EnterFault.wrongCode => l10n.linkEnterWrongCode,
      _EnterFault.expired => l10n.linkEnterExpired,
      _EnterFault.tooManyAttempts => say(l10n.commonRetryLater, 'E-LINK-429'),
      _EnterFault.offline => say(l10n.linkEnterOffline, 'E-NET'),
      _EnterFault.failed => say(l10n.linkEnterFailed, 'E-LINK'),
    };
  }
}

/// 연결 암호 넣기 — **이룸이 휴대폰** (이슈 #205 · 명세 §5-2).
///
/// 로그인 전에 서는 화면이다. 여섯 칸을 채우면 `시작하기`가 켜지고, 누르면 계정에 붙어
/// 이룸이 홈으로 간다 (Figma `코드연결` 1274:7909 · `코드연결_입력` 1274:7988, #493).
///
/// 시안이 버튼을 그려서 **다 채우면 바로 보내던 동작을 버튼으로 옮겼다.** 시안 이전에는
/// 확인 버튼이 없어 자동으로 보냈다(#205 §5-2).
///
/// PIN 화면과 달리 **시스템 키보드**를 쓴다 — 암호에 영문이 섞여 숫자패드로는 칠 수 없다.
/// 6칸 모양은 PIN과 맞추되 글자를 드러낸다(가리면 받아적을 수 없다).
class LinkEnterScreen extends ConsumerStatefulWidget {
  const LinkEnterScreen({super.key});

  @override
  ConsumerState<LinkEnterScreen> createState() => _LinkEnterScreenState();
}

class _LinkEnterScreenState extends ConsumerState<LinkEnterScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  _EnterError? _error;

  /// 연결이 밖에서 끊겨 이 화면에 왔다 (#363). 보호자가 끊었거나 세션이 끝났다.
  ///
  /// 시안 §8-5 는 `다음에 열 때 연결이 끊어졌어요`를 말한다. 앱이 꺼져 있는 사이에 끊겨도 알 수 있게
  /// 저장된 표식을 읽는다 — 스스로 로그아웃한 사람에게는 서 있지 않다.
  late final bool _linkLost = ref.read(deviceLinkRepositoryProvider).linkWasLost;

  /// 틀린 횟수. 값이 바뀔 때마다 칸이 한 번 흔들린다.
  int _failCount = 0;

  /// 서버에 보내는 중. 같은 암호를 두 번 보내지 않는다 — 1회용이라 두 번째는 반드시 실패한다.
  bool _sending = false;

  String get _typed => LinkCode.normalize(_controller.text);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_sending) return;
    // 칸과 시작하기(여섯 자일 때만 켜짐)를 다시 그린다
    setState(() {});
  }

  Future<void> _submit() async {
    final code = _typed;
    if (!LinkCode.hasValidShape(code)) {
      // 우리가 만들 수 없는 모양은 서버에 보내지 않는다 — 시도 횟수만 축낸다.
      _fail(const _EnterError(_EnterFault.wrongCode));
      return;
    }

    setState(() => _sending = true);
    _focusNode.unfocus();
    final result = await ref.read(deviceLinkRepositoryProvider).redeem(code);
    if (!mounted) return;
    setState(() => _sending = false);

    switch (result.outcome) {
      case RedeemOutcome.linked:
        context.go(Routes.child);
      case RedeemOutcome.notFound:
        _fail(const _EnterError(_EnterFault.wrongCode));
      case RedeemOutcome.expired:
        _fail(const _EnterError(_EnterFault.expired));
      case RedeemOutcome.tooManyAttempts:
        _fail(_EnterError(_EnterFault.tooManyAttempts, result.failure));
      case RedeemOutcome.offline:
        _fail(_EnterError(_EnterFault.offline, result.failure));
      case RedeemOutcome.failed:
        _fail(_EnterError(_EnterFault.failed, result.failure));
    }
  }

  /// 실패 — 입력을 비우고 흔들어 알린다. 붉은 경고를 크게 쓰지 않는다 (§5-2).
  void _fail(_EnterError error) {
    _controller.clear();
    setState(() {
      _error = error;
      _failCount++;
    });
    // 다음 프레임에 연다 — 화면에 처음 들어올 때와 같은 방식이다. 같은 프레임에서
    // 포커스를 잡으면 Android 가 키보드를 올리지 않았다 (실측).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openKeyboard();
    });
  }

  /// 키보드를 연다 — **포커스가 이미 있어도** 입력 연결을 새로 잡는다 (#428).
  ///
  /// 보낼 때 키보드를 내렸다가 실패하면 포커스만 돌아오고 키보드는 내려간 채였다.
  /// 그 뒤 칸을 누르면 `requestFocus` 는 이미 포커스가 있어 아무 일도 하지 않아,
  /// 뒤로 나갔다 들어오기 전에는 다시 칠 수 없었다 (Android·iOS 실측).
  ///
  /// 키보드만 다시 띄우면(`TextInput.show`) 키보드는 올라와도 **친 글자가 칸에
  /// 들어가지 않았다** — 입력 연결은 끊긴 채였다 (Android 실측). 그래서 포커스를
  /// 한 번 풀고 다음 프레임에 다시 잡아 연결부터 새로 만든다.
  void _openKeyboard() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
      return;
    }
    _focusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  /// 시안 `1274:7909` — 뒤로가기 하단(119)에서 코드 칸 윗변(339)까지.
  /// 머리 글(제목 + 설명)이 한 줄이든 두 줄이든 칸이 이 자리에 선다.
  static const _headerRegionHeight = 220.0;

  /// 뒤로가기. **어떤 길로 들어왔든 막다른 화면이 되지 않게 한다** (#542).
  ///
  /// 이 화면은 여러 곳에서 온다 — 역할 선택, 앱 시작, 세션 종료. 아래에 돌아갈 화면이 없으면 pop 이 아무 일도
  /// 하지 않아 사용자가 갇혔다. 그때는 [linkEnterBackTarget] 과 같은 규칙으로 갈 곳을 정해 직접 옮긴다.
  void _back() {
    if (context.canPop()) {
      context.popOrHome();
      return;
    }
    context.go(
      linkEnterBackTarget(
        hasSession: ref.read(authRepositoryProvider).hasSession,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final l10n = context.l10n;
    final error = _error;

    return ElumScaffold(
      onBack: _sending ? null : _back,
      // 여섯 칸을 다 채워야 켜진다. 보내는 중에는 다시 누를 수 없다 — 1회용 암호다.
      bottomButton: ElumButton(
        label: l10n.linkEnterStartButton,
        onPressed: _typed.length == LinkCode.length && !_sending
            ? _submit
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _headerRegionHeight.h,
            child: ElumHeader(
              title: l10n.linkEnterTitle,
              // 틀린 암호 안내가 있으면 그것이 먼저다 — 지금 일어난 일이다.
              // 안내(시안 문구)의 밑줄 친 부분이 보호자 휴대폰에서 코드를 찾는 길이다.
              description:
                  error?.message(l10n) ??
                  (_linkLost ? l10n.linkEnterLinkLost : l10n.linkEnterGuide),
              underlinedInDescription: error == null && !_linkLost
                  ? l10n.linkEnterGuidePath
                  : null,
            ),
          ),
          // 실제 입력칸은 투명이라 화면 낭독기에서 빠진다. 키보드를 여는 길은 이
          // 여섯 칸뿐이라 이름을 주고, 칸에 보이는 글자는 값으로 함께 읽힌다 (#339).
          Semantics(
            container: true,
            button: true,
            label: l10n.linkEnterInputLabel,
            value: _typed,
            child: GestureDetector(
              onTap: _openKeyboard,
              behavior: HitTestBehavior.opaque,
              child: AppShake(
                trigger: _failCount,
                // 칸마다 글자를 따로 읽으면 한 글자씩 끊겨 들린다 — 위 값 하나로
                // 읽힌다. 바깥에서 빼면 누름 동작까지 함께 빠져 안쪽에서 뺀다.
                child: ExcludeSemantics(
                  child: CodeBoxes.figma(
                    value: _typed,
                    hasError: error != null,
                  ),
                ),
              ),
            ),
          ),
          if (_sending) ...[
            SizedBox(height: space.lg),
            Center(child: SizedBox(
              width: space.lg.w, height: space.lg.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )),
          ],
          // 화면에 보이지 않는 실제 입력칸. 시스템 키보드를 쓰되 자동완성·자동수정을 끈다 —
          // 켜 두면 영문 여섯 자를 단어로 고쳐 버린다.
          SizedBox(
            height: 0,
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.visiblePassword,
                maxLength: LinkCode.length + 2, // 공백을 끼워 쳐도 받아준다
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
