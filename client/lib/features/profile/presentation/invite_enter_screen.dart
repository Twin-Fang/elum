import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/app_shake.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/utils/korean_particle.dart';
import '../../link/domain/link_code.dart';
import '../../link/presentation/widgets/code_boxes.dart';
import '../application/profile_session.dart';
import '../data/profile_repository.dart';
import '../domain/invite_problem.dart';

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
class InviteEnterScreen extends ConsumerStatefulWidget {
  const InviteEnterScreen({super.key});

  @override
  ConsumerState<InviteEnterScreen> createState() => _InviteEnterScreenState();
}

class _InviteEnterScreenState extends ConsumerState<InviteEnterScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String? _errorMessage;

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
    if (_sending || _locked) return;
    setState(() {});
    // 여섯 자를 채우면 바로 보낸다 — 확인 버튼을 따로 누르게 하지 않는다 (연결 암호와 같다).
    if (_typed.length == LinkCode.length) _submit();
  }

  Future<void> _submit() async {
    if (_sending || _locked) return;
    final code = _typed;
    if (!LinkCode.hasValidShape(code)) {
      // 우리가 만들 수 없는 모양은 서버에 보내지 않는다 — 계정당 시도 한도만 축낸다.
      _fail('초대 코드가 맞지 않아요 (E-INV-FORM)');
      return;
    }

    setState(() {
      _sending = true;
      _offline = false;
    });
    _focusNode.unfocus();
    final attempt = await ref.read(profileRepositoryProvider).redeemInvite(code);
    if (!mounted) return;
    setState(() => _sending = false);

    if (attempt.isOk) {
      await _joined(attempt.value!);
      return;
    }
    await _handleFailure(attempt.failure!);
  }

  Future<void> _joined(ProfileJoin join) async {
    // 합류한 이룸이를 고르고 이룸이별 값(이름·캐릭터·일과)을 맞춘다.
    await ref.read(profileSessionProvider.notifier).joined(join);
    if (!mounted) return;
    final name = join.profile.displayName;
    // 화면을 옮기기 전에 잡아 둔다 — 옮긴 뒤에는 이 화면의 context 가 없다.
    final messenger = ScaffoldMessenger.of(context);
    context.go(Routes.guardian);
    messenger.showSnackBar(
      SnackBar(content: Text('$name${name.objectParticle} 함께 돌보게 됐어요')),
    );
  }

  Future<void> _handleFailure(AppFailure failure) async {
    String say(String fallback, String code) => failure.describe(fallback, code);

    switch (InviteProblem.of(failure)) {
      case InviteProblem.notFound:
        _fail(say('초대 코드가 맞지 않아요', 'E-INV-404'));
      case InviteProblem.expired:
        _fail(say('초대 코드가 만료됐어요. 새 코드를 받아주세요', 'E-INV-410'));
      case InviteProblem.tooManyAttempts:
        // 잠근다 — 더 입력하면 시도만 늘고 같은 이유로 막힌다.
        _fail(say('잠시 뒤에 다시 해주세요', 'E-INV-429'), lock: true);
      case InviteProblem.alreadyGuardian:
        _fail(say('이미 함께하고 있는 이룸이예요', 'E-INV-409'));
      case InviteProblem.forbiddenForElumi:
        _fail(say('이룸이 휴대폰에서는 할 수 없어요', 'E-INV-403'), lock: true);
      case InviteProblem.invalidInput:
        _fail(say('초대 코드가 맞지 않아요', 'E-INV-400'));
      case InviteProblem.offline:
        // 입력을 남긴다 — 인터넷이 돌아오면 다시 칠 필요 없이 `다시 시도`만 누르면 된다.
        setState(() {
          _offline = true;
          _errorMessage = say('연결하지 못했어요. 인터넷을 확인해주세요', 'E-NET');
        });
      case InviteProblem.consentRequired:
        await showFailure(
          context,
          failure,
          title: '초대 코드를 넣지 못했어요',
          fallback: '약관에 먼저 동의해주세요',
          fallbackCode: 'E-INV-CONSENT',
        );
        if (mounted) context.go(Routes.consent);
      case InviteProblem.other:
        _fail(say('연결하지 못했어요. 다시 해주세요', 'E-INV'));
    }
  }

  /// 실패 — 입력을 비우고 흔들어 알린다. 붉은 경고를 크게 쓰지 않는다.
  void _fail(String message, {bool lock = false}) {
    _controller.clear();
    setState(() {
      _errorMessage = message;
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
      onBack: _sending ? null : () => context.pop(),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              title: '초대 코드를\n넣어주세요',
              description: _errorMessage ?? '함께하는 보호자에게 받은 여섯 글자예요',
            ),
            SizedBox(height: space.lg),
            // 어디서 받는지 적어 준다. 받는 사람은 처음 보는 화면이다.
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
                    '함께하는 보호자 휴대폰에서',
                    style: context.typo.body.copyWith(color: colors.textSecondary),
                  ),
                  SizedBox(height: space.sm),
                  Text(
                    '설정 → 함께하는 사람',
                    style: context.typo.subtitle.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: space.sm),
                  Text(
                    '초대 코드를 만들면 여섯 글자가 나와요',
                    style: context.typo.body.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(height: space.xl),
            // 실제 입력칸은 투명이라 화면 낭독기에서 빠진다. 키보드를 여는 길은 이 여섯 칸뿐이라
            // 이름을 주고, 칸에 보이는 글자는 값으로 함께 읽힌다 (연결 암호 #339 와 같다).
            Semantics(
              container: true,
              button: true,
              label: '초대 코드 넣기',
              value: _typed,
              child: GestureDetector(
                onTap: _openKeyboard,
                behavior: HitTestBehavior.opaque,
                child: AppShake(
                  trigger: _failCount,
                  child: ExcludeSemantics(
                    child: CodeBoxes(value: _typed, hasError: _errorMessage != null),
                  ),
                ),
              ),
            ),
            if (_sending) ...[
              SizedBox(height: space.lg),
              Center(
                child: SizedBox(
                  width: space.lg.w,
                  height: space.lg.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
            if (_offline && !_sending) ...[
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
                      '다시 시도',
                      style: context.typo.linkLater.copyWith(
                        color: colors.linkLaterLabel,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
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
                  enabled: !_locked,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.visiblePassword,
                  // 공백·하이픈을 끼워 쳐도 받아준다 (서버도 받는다)
                  maxLength: LinkCode.length + 2,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
