import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_shake.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/show_failure.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../onboarding/domain/onboarding_profile.dart';
import '../../onboarding/presentation/widgets/pin_keypad.dart';

/// 설정 → 비밀암호 변경하기 (#437).
///
/// **시안이 없다.** 설정 시안(`1022:4467`)에는 줄만 있어, 온보딩 비밀번호 화면
/// (`238:1909` · `238:2767`)의 점·키패드·간격을 그대로 쓴다. 시안 요청은 #438.
///
/// 지금 암호를 **먼저 묻는다.** 보호자 화면이 열린 휴대폰을 이룸이가 들고 있을 때
/// 바로 바꿀 수 있으면 보호자 화면을 지키는 암호가 의미를 잃는다.
class PinChangeScreen extends ConsumerStatefulWidget {
  const PinChangeScreen({super.key, this.createOnly = false});

  /// 암호가 없는 휴대폰이 보호자 화면에 들어오려고 처음 만드는 경우 (#355).
  ///
  /// 문구가 "바꾸기"가 아니라 "만들기"가 되고, 저장하면 설정으로 돌아가는 대신
  /// 보호자 홈으로 들어간다. 입력 단계는 설정과 같다.
  final bool createOnly;

  @override
  ConsumerState<PinChangeScreen> createState() => _PinChangeScreenState();
}

enum _Step { verify, enter, confirm }

class _PinChangeScreenState extends ConsumerState<PinChangeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// 저장된 암호. 읽기 전에는 null — 그동안 점만 보여준다.
  String? _saved;
  bool _loaded = false;

  _Step _step = _Step.verify;

  /// 새 암호(2단계 입력). 한번 더가 틀려도 살린다 — 온보딩과 같다.
  String? _newPin;

  /// 틀림 안내를 띄우는 중인가. 문구는 글자가 아니라 이 표시로 들고 있다가 `build` 에서 푼다.
  bool _mismatched = false;

  /// 틀린 횟수. 값이 바뀔 때마다 점이 한 번 흔들린다.
  int _mismatchCount = 0;
  bool _saving = false;

  String get _current => _controller.text;
  static const _len = OnboardingProfile.pinLength;

  bool get _canSave =>
      _step == _Step.confirm && _current.length == _len && _current == _newPin;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await ref.read(localStorageProvider).getPin();
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _loaded = true;
      // 암호를 정한 적 없는 휴대폰(온보딩을 건너뛴 개발 상태)은 확인할 것이 없다.
      // 모드 전환 화면도 이때 그냥 통과시킨다.
      if (saved == null || saved.isEmpty) _step = _Step.enter;
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    // 다시 누르기 시작하면 실패 안내를 거둔다. 비우는 순간(빈 값)에는 남겨 둔다 —
    // 방금 띄운 안내가 곧바로 사라져 무엇이 틀렸는지 읽을 틈이 없어진다.
    setState(() {
      if (_mismatched && _current.isNotEmpty) _mismatched = false;
    });
    if (!_loaded || _current.length != _len) return;

    switch (_step) {
      case _Step.verify:
        _current == _saved ? _next(_Step.enter) : _mismatch();
      case _Step.enter:
        final entered = _current;
        _next(_Step.confirm, keep: entered);
      case _Step.confirm:
        // 맞으면 키패드를 내려 `저장하기`를 드러낸다. 가려 두면 다 넣고도 다음에
        // 뭘 할지 모른다 — 온보딩에서 실제로 막혔다.
        _current == _newPin ? _revealSave() : _mismatch();
    }
  }

  /// 다음 단계로. clear()가 _onChanged 를 다시 부르므로 프레임 이후로 미룬다.
  void _next(_Step step, {String? keep}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _step = step;
        if (keep != null) _newPin = keep;
      });
      _clearInput();
    });
  }

  /// 틀렸다 — 입력만 비우고 흔든다. 경고색·아이콘은 쓰지 않는다 (입력 오류 규칙).
  void _mismatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _clearInput();
      setState(() {
        // 시안(`1274:9466`)은 `다시 입력해주세요` 다. 만들기(createOnly)는 온보딩 문구를 따른다.
        _mismatched = true;
        _mismatchCount++;
      });
    });
  }

  void _revealSave() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.unfocus();
    });
  }

  void _clearInput() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _save() async {
    if (_saving) return;
    final pin = _current;
    setState(() => _saving = true);
    final storage = ref.read(localStorageProvider);
    await storage.setPin(pin);
    // `setPin` 은 저장 실패를 삼킨다(로그만 남긴다). 다시 읽어 봐야 실제로 바뀌었는지
    // 안다. 바뀌지 않았는데 "바꿨어요"라고 하면 다음 전환 때 새 암호가 안 먹는다.
    final stored = await storage.getPin();
    if (!mounted) return;
    setState(() => _saving = false);

    if (stored != pin) {
      await showFailure(
        context,
        null,
        title: widget.createOnly
            ? context.l10n.pinChangeCreateFailedTitle
            : context.l10n.pinChangeFailedTitle,
        fallback: context.l10n.pinChangeFailedFallback,
        fallbackCode: 'E-PIN',
      );
      return;
    }
    // 성공 알림은 스낵바다 — 실패만 팝업으로 막는다 (#433).
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (widget.createOnly) {
      // 방금 만든 암호가 곧 통과의 증거다. 보호자 홈으로 바로 들어간다.
      context.go(Routes.guardian);
    } else {
      context.pop();
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.createOnly
              ? l10n.pinChangeCreatedSnack
              : l10n.pinChangeChangedSnack,
        ),
      ),
    );
  }

  (String, String?) get _copy => switch (_step) {
    // 시안(`1027:4683`)은 설명이 없다
    _Step.verify => (context.l10n.pinChangeVerifyTitle, null),
    _Step.enter when widget.createOnly => (
      // 온보딩 비밀번호 화면(238:1909)과 같은 문구
      context.l10n.pinChangeCreateTitle,
      context.l10n.pinModeHint,
    ),
    _Step.enter => (context.l10n.pinChangeEnterTitle, context.l10n.pinModeHint),
    // 만들기는 온보딩 재입력(238:2767)과 같은 문구다
    _Step.confirm when widget.createOnly => (
      context.l10n.pinChangeCreateConfirmTitle,
      context.l10n.pinModeHint,
    ),
    // 바꾸기는 시안 `1274:9661` — 제목이 `비밀암호를`, 설명은 끝이 가까웠다는 말이다
    _Step.confirm => (
      context.l10n.pinChangeConfirmTitle,
      context.l10n.pinChangeConfirmHint,
    ),
  };

  /// 설명 하단 → 점. 온보딩 비밀번호 화면(`238:1996`)과 같은 값이다.
  static const _descriptionToDots = 72.0;

  /// 바꾸기(설정에서 들어옴)는 시안(`1027:4683` 외)이 설정 계열 머리를 쓴다 — 뒤로가기 줄(y=67)에
  /// `비밀암호 변경하기` 제목이 서고 큰 제목은 y=148 에서 시작한다. 점 자리(y≈299)는 그대로라
  /// 설명과 점 사이가 그만큼(17) 줄어든다.
  static const _changeBackTop = 67.0;
  static const _changeTitleY = 148.0;
  static const _changeDescriptionToDots = 55.0;

  @override
  Widget build(BuildContext context) {
    final (title, description) = _copy;
    // 틀림 문구는 상태에 글자로 두지 않는다 — 언어가 바뀌면 옛 언어로 남는다.
    final errorMessage = !_mismatched
        ? null
        : widget.createOnly
        ? context.l10n.pinChangeMismatchCreate
        : context.l10n.pinChangeMismatch;
    // 만들기(createOnly)는 온보딩 머리 그대로다. 바꾸기만 설정 계열 머리다.
    final change = !widget.createOnly;
    return ElumScaffold(
      onBack: () => context.pop(),
      title: change ? context.l10n.pinChangeHeaderTitle : null,
      backTop: change ? _changeBackTop : null,
      // 온보딩처럼 **다 맞았을 때만** 버튼이 나타난다 (#231). 나타나는 것이 신호다.
      bottomButton: _canSave
          ? ElumButton(
              label: context.l10n.pinChangeSave,
              onPressed: _saving ? null : _save,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            title: title,
            titleY: change ? _changeTitleY : null,
            description: errorMessage ?? description,
            // 틀림 안내만 붉다 (시안 `1274:9466` — #DA5050). 만들기는 온보딩처럼 보조색이다.
            descriptionColor: errorMessage != null && !widget.createOnly
                ? context.colors.settingsDestructive
                : null,
          ),
          SizedBox(
            height: (change ? _changeDescriptionToDots : _descriptionToDots).h,
          ),
          // 실제 입력칸은 투명이라 낭독기에서 빠진다. 키패드를 여는 길은 이 점
          // 자리뿐이라 이름을 준다 (#339). 넣은 숫자는 암호라 읽지 않는다.
          Semantics(
            container: true,
            button: true,
            label: context.l10n.pinChangeInputLabel,
            child: GestureDetector(
              onTap: _focusNode.requestFocus,
              behavior: HitTestBehavior.opaque,
              child: AppShake(
                trigger: _mismatchCount,
                child: PinDots(length: _len, filled: _current.length),
              ),
            ),
          ),
          PinInputField(
            controller: _controller,
            focusNode: _focusNode,
            maxLength: _len,
          ),
        ],
      ),
    );
  }
}
