import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/child_haptics.dart';
import '../../../core/l10n/current_l10n.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_shake.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import '../../../core/widgets/pin_forgot_dialog.dart';
import '../../../core/widgets/show_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../onboarding/domain/onboarding_profile.dart';
import '../../onboarding/presentation/widgets/pin_keypad.dart';
import '../../../core/router/pop_or_home.dart';
import '../application/mode_switch_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/logger/app_logger.dart';

/// Figma `보호자_아이화면_전환`(309:2837).
///
/// **양방향으로 쓰인다.** Figma에 두 벌이 있는데 문구만 다르다. 화면을 둘로
/// 나누면 PIN 입력 로직이 복제되므로 목적지를 파라미터로 받는다.
///
/// PIN이 틀려도 **경고색·에러 아이콘을 쓰지 않는다.** 아동도 보는 화면이다.
class ModeSwitchScreen extends ConsumerStatefulWidget {
  const ModeSwitchScreen({super.key, required this.target});

  /// 어디로 갈 것인가. 문구와 이동 경로가 갈린다.
  final ModeSwitchTarget target;

  @override
  ConsumerState<ModeSwitchScreen> createState() => _ModeSwitchScreenState();
}

class _ModeSwitchScreenState extends ConsumerState<ModeSwitchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// 틀린 횟수. [AppShake]의 trigger로 쓴다 — 값이 바뀔 때마다 흔들린다.
  /// 이 화면에서만 센다 (나갔다 오거나 앱을 다시 켜면 0)
  int _mismatchCount = 0;

  /// 「비밀암호를 잊었어요」를 꺼내는 틀린 횟수 (처음부터 보이면 이룸이가 눌러 로그아웃할 수 있음. 5회면 잠김)
  static const _mismatchCountBeforeRecovery = 3;

  /// 잊었어요 글자 버튼을 보일지: 결제 확인이 아니고, 이 화면에서 여러 번 틀렸을 때만
  bool get _shouldShowPinRecovery =>
      widget.target.canOfferPinRecovery &&
      _mismatchCount >= _mismatchCountBeforeRecovery;

  /// 암호가 틀렸는가. true면 설명 자리에 실패 안내를 보인다.
  /// 문구가 아니라 상태만 들고 있어야 앱 언어가 바뀌어도 새 언어로 읽힌다.
  bool _mismatch = false;

  /// 보호자 화면으로 갈 때 저장된 암호가 없는 이룸이 휴대폰이다.
  /// 이때는 입력창 대신 안내만 보인다.
  bool _blocked = false;
  bool _verifying = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    // 입력을 받기 전에 암호가 있는지부터 본다. 숫자를 다 넣은 뒤에야 "만들어라"를
    // 하면 이미 넣은 네 자리가 무엇이었는지 모호해진다.
    _guardGuardianEntry();
  }

  /// 저장된 암호를 읽는다. 읽기에서 예외가 나면 실패 팝업을 띄우고 null 이 아니라
  /// `ok=false` 로 알린다 — 읽지 못한 것을 "암호 없음"으로 보면 그대로 열어 주게 된다.
  Future<({bool ok, bool hasPin})> _readPin() async {
    try {
      return (ok: true, hasPin: await ref.read(modeSwitchControllerProvider).hasPin());
    } catch (e, stack) {
      AppLogger.error('[mode switch] pin read failed', e, stack);
      if (!mounted) return (ok: false, hasPin: false);
      await showFailure(
        context,
        e,
        title: context.l10n.modeSwitchReadFailedTitle,
        fallback: context.l10n.modeSwitchReadFailedFallback,
        fallbackCode: 'E-PIN-READ',
      );
      return (ok: false, hasPin: false);
    }
  }

  /// 보호자 화면 입구를 지킨다.
  ///
  /// 암호가 없는 휴대폰은 **비교 없이 통과시키지 않는다.** 연결 암호로 붙은 이룸이 휴대폰과
  /// 다시 로그인한 보호자 휴대폰이 실제로 이 상태가 되므로 열어 줄 수 없다.
  ///
  /// - 보호자 휴대폰: 암호를 새로 만들게 한다. 정한 사람만 아는 값이 생기므로 막은 것이다.
  /// - 이룸이 휴대폰: 암호를 만들게 하면 이룸이가 직접 정해 들어올 수 있다. 막고
  ///   안내만 보인다.
  Future<void> _guardGuardianEntry() async {
    final read = await _readPin();
    if (!mounted) return;
    if (!read.ok) {
      // 빈 화면에 남지 않게 돌려보낸다
      context.popOrHome();
      return;
    }
    if (read.hasPin || !widget.target.isGuardianEntry) {
      setState(() => _ready = true);
      return;
    }

    if (ref.read(modeSwitchControllerProvider).isElumiDevice) {
      setState(() => _blocked = true);
      return;
    }
    // 잠금 부재는 보호자 재로그인으로 처리해 이룸이의 임의 암호 생성을 막는다.
    context.go(Routes.login);
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
    setState(() {
      // 다시 누르기 시작하면 실패 안내를 거둔다 — 남겨두면 지금 틀린 것처럼 보인다.
      if (_mismatch && _controller.text.isNotEmpty) {
        _mismatch = false;
      }
    });
    if (_ready && !_verifying && _controller.text.length == OnboardingProfile.pinLength) _verify();
  }

  Future<void> _verify() async {
    if (_verifying || !_ready) return;
    // 확인 중 표시 (점 깜박임). 확인 계산이 화면을 잠시 붙잡으므로 흐린 점을 먼저 한 프레임 그린다
    setState(() => _verifying = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final entered = _controller.text;
    bool isValid;
    try {
      final controller = ref.read(modeSwitchControllerProvider);
      final hasPin = await controller.hasPin();
      if (!mounted) return;
      if (!hasPin && widget.target.isGuardianEntry) {
        _ready = false;
        await _guardGuardianEntry();
        return;
      }
      isValid = !hasPin || await controller.verifyPin(entered);
    } catch (e) {
      if (mounted) {
        _controller.clear();
        await showFailure(context, null,
          title: context.l10n.modeSwitchReadFailedTitle,
          fallback: context.l10n.modeSwitchReadFailedFallback,
          fallbackCode: e.toString().contains('E-PIN-LOCKED') ? 'E-PIN-LOCKED' : 'E-PIN',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
    if (!mounted) return;

    if (isValid) {
      playChildHaptic(context, ChildHapticKind.unlock);
      final route = widget.target.route;
      // 결제 확인은 화면을 옮기지 않고 연 쪽에 "맞음"을 돌려준다
      if (route == null) {
        Navigator.of(context).pop(true);
      } else {
        context.go(route);
      }
      return;
    }

    // 틀렸다 — 점을 흔들고 점 아래 줄에 문구로 알린다.
    // 입력만 조용히 비우면 틀린 것인지, 입력이 안 먹은 것인지, 화면이 멈춘
    // 것인지 구분할 수 없어 같은 암호를 다시 누르게 된다.
    //
    // 색 대신 [AppShake]로 알린다 — 아동도 보는 화면이라 경고색을 쓰지 않는다.
    // 온보딩 PIN 화면(pin_screen)과 같은 방식이다.
    //
    // 비우는 것은 다음 프레임에 한다. 지금은 _onChanged가 도는 중이라
    // 여기서 clear하면 그 리스너가 곧바로 _mismatch를 꺼버린다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.clear();
      _focusNode.requestFocus();
      // 진동은 이룸이 스위치를 따른다 — AppShake 의 기본 진동은 스위치를 보지 않는다
      playChildHaptic(context, ChildHapticKind.error);
      setState(() {
        _mismatch = true;
        _mismatchCount++;
      });
    });
  }

  /// 비밀암호를 잊었을 때: 안내 팝업 > 다시 로그인 고르면 로그아웃(잠금도 지움) > 로그인 화면
  ///
  /// 보호자 계정으로 다시 로그인한 기기는 로그인 뒤 암호 만들기로 이어진다
  Future<void> _onForgotPin() async {
    playChildHaptic(context, ChildHapticKind.tap);
    final isReloginChosen = await confirmPinForgotRelogin(context);
    if (!isReloginChosen || !mounted) return;
    try {
      await ref.read(authSessionControllerProvider).logout();
    } catch (e, stack) {
      // 정리에 실패해도 로그인으로는 간다. 남은 세션은 다음 시작에 다시 정리된다
      AppLogger.error('[mode switch] forgot pin logout failed', e, stack);
    }
    if (mounted) context.go(Routes.login);
  }

  /// 설명 하단(193) → 점(299). 시안 `309:2837` 실측.
  ///
  /// **점은 비밀번호 화면과 같은 y=299에 있다.** 다만 이 화면은 제목이 한 줄이라
  /// 설명이 위(177)에 서고, 그래서 남는 간격이 106으로 더 크다. 거기 72를 쓰면
  /// 점이 34 떠 오른다.
  static const _descriptionToDots = 106.0;

  @override
  Widget build(BuildContext context) {
    if (_blocked) {
      return ElumScaffold(
        onBack: context.popOrHome,
        bottomButton: ElumButton(
          label: context.l10n.modeSwitchBlockedBack,
          onPressed: () {
            playChildHaptic(context, ChildHapticKind.tap);
            context.popOrHome();
          },
        ),
        child: ElumHeader(
          title: context.l10n.modeSwitchBlockedTitle,
          description: context.l10n.modeSwitchBlockedDescription,
        ),
      );
    }
    return ElumScaffold(
      onBack: context.popOrHome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 제목·설명을 손으로 쌓지 않는다 — 뼈대가 쓰는 간격과 어긋난다.
          // 실제로 `space.xl`(32)을 쓰다 제목이 20 내려가 있었다.
          ElumHeader(
            // 시안 `309:2837` 문구 그대로
            title: context.l10n.modeSwitchTitle,
            // 틀림 안내는 설명 자리가 아니라 점 아래 줄에 둔다 (회색 설명 자리에서는 거의 안 보인다)
            description: widget.target.description,
          ),
          SizedBox(height: _descriptionToDots.h),
          // 점을 누르면 키패드가 다시 올라온다 (내려버렸을 때의 탈출구)
          // 실제 입력칸은 투명(Opacity 0)이라 화면 낭독기에서 빠진다. 키보드를 여는
          // 길은 이 점 자리뿐이라 이름을 준다. 넣은 숫자는 암호라 읽지 않는다.
          Semantics(
            container: true,
            button: true,
            label: context.l10n.modeSwitchPinLabel,
            child: GestureDetector(
              onTap: _focusNode.requestFocus,
              behavior: HitTestBehavior.opaque,
              child: AppShake(
                trigger: _mismatchCount,
                haptic: false,
                child: PinVerifyingPulse(
                  isVerifying: _verifying,
                  child: PinDots(
                    length: OnboardingProfile.pinLength,
                    filled: _controller.text.length,
                  ),
                ),
              ),
            ),
          ),
          PinErrorMessage(
            message: _mismatch ? context.l10n.modeSwitchMismatch : null,
          ),
          if (_shouldShowPinRecovery) ...[
            SizedBox(height: context.space.md.h),
            Center(
              child: ElumSecondaryButton(
                label: context.l10n.pinForgotLink,
                onTap: _onForgotPin,
                isCompact: true,
              ),
            ),
          ],
          PinInputField(
            controller: _controller,
            focusNode: _focusNode,
            maxLength: OnboardingProfile.pinLength,
          ),
        ],
      ),
    );
  }
}

/// 전환 목적지. 문구와 경로가 함께 붙어 있어야 어긋나지 않는다.
enum ModeSwitchTarget {
  // 시안(`309:2837`)은 `암호를 입력하면 보호자 화면으로 전환돼요`다.
  // `입력하면`은 시안을 따르고, 끝은 **능동형**으로 둔다 — 피동형(`전환돼요`)은
  // 루트 CLAUDE.md 말투 규칙이 금지한다.
  child(Routes.child),
  guardian(Routes.guardian),

  /// 결제 직전 보호자 확인 (`Routes.guardianPlanPin`). 화면을 옮기지 않고 true 로 닫힌다
  purchase(null);

  const ModeSwitchTarget(this.route);

  /// 맞으면 갈 곳. null 이면 연 쪽으로 돌아간다
  final String? route;

  /// 보호자 쪽으로 들어가는 확인인가 (암호가 없으면 통과시키지 않는다)
  bool get isGuardianEntry => this != child;

  /// 「비밀암호를 잊었어요」를 보일지. 결제 확인은 닫고 돌아가면 되므로 다시 로그인 길을 두지 않는다
  bool get canOfferPinRecovery => this != purchase;

  /// 암호 안내 문구. 읽을 때 푼다 — 값으로 들고 있으면 앱 언어가 바뀐 뒤에도 옛 언어가 남는다.
  String get description => switch (this) {
    ModeSwitchTarget.child => appL10n.modeSwitchToChild,
    ModeSwitchTarget.guardian => appL10n.modeSwitchToGuardian,
    ModeSwitchTarget.purchase => appL10n.modeSwitchToPurchase,
  };

  /// 쿼리 파라미터에서 복원한다. 모르는 값이면 아이 화면으로 본다.
  /// 결제 확인은 쿼리로 열지 않는다 (보호자 경로 `Routes.guardianPlanPin` 으로만 연다)
  static ModeSwitchTarget fromName(String? name) {
    for (final t in values) {
      if (t != purchase && t.name == name) return t;
    }
    return child;
  }
}
