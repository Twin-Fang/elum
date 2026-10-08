import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_info_tile.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/haptics/child_haptics.dart';
import '../../../core/widgets/settings_switch_tile.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/presentation/consent_document_list_screen.dart';
import '../../link/data/device_link_repository.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../profile/application/profile_session.dart';
import 'widgets/ai_credit_card.dart';
import '../../../core/router/pop_or_home.dart';
import '../../member/application/member_providers.dart';
import '../../../core/router/routes.dart';

/// 보호자 설정 화면.
///
/// 지금은 계정 항목 둘뿐이지만 **목록 구조**로 만들어 이후 항목(암호 변경·알림 등)을
/// 줄만 추가하면 되게 한다. 화면마다 다른 레이아웃을 짜면 항목이 늘 때 흐트러진다.
///
/// 아이 화면에는 진입점을 두지 않는다 — 아이가 계정을 정리할 이유가 없다.
class GuardianSettingsScreen extends ConsumerStatefulWidget {
  const GuardianSettingsScreen({super.key});

  @override
  ConsumerState<GuardianSettingsScreen> createState() =>
      _GuardianSettingsScreenState();
}

class _GuardianSettingsScreenState
    extends ConsumerState<GuardianSettingsScreen> {
  /// 처리 중 중복 탭 방지. 로그아웃은 서버 요청이 섞여 있어 즉시 끝나지 않는다.
  bool _busy = false;

  Future<void> _logout() async {
    // 시안(`팝업` 1045:5194 `로그아웃/회원탈퇴`)은 **가운데 팝업**이다.
    // 바텀시트로 따로 그려 두고 있었는데, 그러면 같은 확인을 앱이 두 가지
    // 모양으로 하게 된다 — 일과 삭제는 팝업, 로그아웃은 시트였다.
    final ok = await showElumDialog<bool>(
      context: context,
      // 시안에 노란 변형이 없으므로 로그아웃도 시안 그대로 붉게 칠한다.
      // 되돌릴 수 없는 탈퇴와는 설명 문장 유무로 구분된다.
      icon: ElumDialogIcon.alert,
      title: context.l10n.guardianSettingsLogoutConfirmTitle,
      actions: [
        ElumDialogAction(
          label: context.l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: context.l10n.commonConfirm,
          value: true,
          tone: ElumDialogTone.danger,
        ),
      ],
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(authSessionControllerProvider).logout();
      // 로그아웃은 이 기기에서 나가는 것이 본질이라 서버가 실패해도 목적은 달성된다.
      return null;
    });
  }

  Future<void> _deleteAccount() async {
    final ok = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: context.l10n.guardianSettingsWithdrawConfirmTitle,
      // **설명 한 줄은 시안에 없지만 남긴다.** 시안은 로그아웃과 회원탈퇴를 한
      // 변형으로 묶어 제목만 두는데, 둘은 결정적으로 다르다 — 로그아웃은
      // 다시 들어오면 그대로지만 탈퇴는 되돌아오지 않는다. 되돌릴 수 없다는
      // 고지를 빼면 사용자가 잃는 것이 크다 (docs 예외처리 규칙).
      // 팝업 컴포넌트는 두 줄 제목을 이미 담는다(`로그인실패` 변형이 그렇다).
      message: context.l10n.guardianSettingsWithdrawConfirmMessage,
      actions: [
        ElumDialogAction(
          label: context.l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: context.l10n.commonConfirm,
          value: true,
          tone: ElumDialogTone.danger,
        ),
      ],
    );
    if (ok != true) return;
    await _run(() => ref.read(authSessionControllerProvider).deleteAccount());
  }

  /// 되돌릴 수 없다고 안내한 동작이 실패했을 때.
  ///
  /// 화면을 옮기지 않는다 — 계정은 서버에 그대로 있고 토큰도 살아 있으므로
  /// 이 자리에서 다시 누르면 된다. 코드(E-DEL)를 같이 보여줘야 제보를 받았을 때
  /// 어디서 멈췄는지 알 수 있다.
  void _tellFailed(AppFailure? failure) {
    // 서버가 이유를 알려줬으면 그 문구가 아래 기본 문구를 이긴다.
    showFailure(
      context,
      failure,
      title: context.l10n.guardianSettingsWithdrawFailedTitle,
      fallback: context.l10n.guardianSettingsWithdrawFailedFallback,
      fallbackCode: 'E-DEL',
    );
  }

  /// 계정 정리 동작의 공통 뼈대.
  ///
  /// 동작이 **실제로 됐는지**를 받아 분기한다. 됐으면 로컬이 비었으니 이 화면에
  /// 남을 수 없어 로그인으로 보내고, 안 됐으면 바뀐 것이 없으니 이 자리에 머문
  /// 채로 알린다.
  Future<void> _run(Future<AppFailure?> Function() action) async {
    setState(() => _busy = true);
    AppFailure? failure;
    try {
      failure = await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (failure == null) {
      // 고른 이룸이(저장소)는 로그아웃·탈퇴의 clearAll 이 이미 지웠다. 메모리의 이룸이 상태와
      // 회원 정보 캐시는 **다음 로그인에서** 버린다 (LoginScreen). 여기서 버리면
      // 이 화면이 아직 떠 있는 동안 회원 정보를 다시 받아 지운 선택을 되살린다.
      context.go(Routes.login);
    } else {
      _tellFailed(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return ElumScaffold(
      onBack: _busy ? null : context.popOrHome,
      // 시안(`1022:4467`)은 제목이 뒤로가기와 **같은 줄**에 선다. 본문에 두면
      // 뒤로가기 아래로 내려간다.
      title: context.l10n.guardianSettingsTitle,
      // 줄이 x=16 에서 시작한다. 뼈대 기본 여백(24)이면 8 만큼 안쪽으로 밀린다.
      backTop: 67,
      horizontalPadding: 16,
      // 설정에는 광고를 두지 않는다. 맨 아래 `회원탈퇴` 줄과 가까워 광고를 잘못 누르면 되돌릴 수 없는
      // 동작으로 이어질 수 있다. 시안에서 간격이 정해지기 전까지 뺀다.
      // 크레딧 카드가 들어와 글꼴을 키우면 한 화면을 넘는다 — 스크롤로 끝까지
      // 볼 수 있게 한다.
      child: SingleChildScrollView(child: _list(space)),
    );
  }

  Widget _list(AppSpacing space) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 시안 첫 줄은 y=147 이다. 뒤로가기 상자 하단(119)에서 28 떨어져 있다.
        SizedBox(height: 40.h),
        // 이번 주 AI 생성. 제목 아래·첫 줄 위 — 꺼져 있으면 자리도 없다.
        const AiCreditCard(),
        _LinkTile(busy: _busy),
        // 다중 보호자. 시안(`1022:4467`)에 없는 줄이라 **임시 시안**이다 — 이룸이 휴대폰
        // 연결 바로 아래에 둔다. 둘 다 "누구와 누구를 잇는가"를 다루는 줄이다.
        _ProfileSwitchTile(busy: _busy),
        SettingsTile(
          label: context.l10n.guardianSettingsPeople,
          onTap: _busy ? null : () => context.push(Routes.guardianPeople),
        ),
        // 계정을 정리하는 항목(로그아웃·탈퇴) 위에 둔다. 읽을거리와 되돌릴 수 없는
        // 동작이 섞이면 실수로 누르기 쉽다.
        SettingsTile(
          label: context.l10n.guardianSettingsDrafts,
          onTap: _busy ? null : () => context.push(Routes.guardianDrafts),
        ),
        // 시안(`1022:4467`) 자리 그대로 — 임시저장과 약관 사이.
        SettingsTile(
          label: context.l10n.guardianSettingsPinChange,
          onTap: _busy ? null : () => context.push(Routes.guardianPinChange),
        ),
        // 카드 그림을 어떤 방식으로 만들지. 시안(`1022:4467`)에 없는 줄이라
        // **임시 시안**이다 — 시안 줄 순서(연결·임시저장·비밀암호·약관)를 깨지 않게
        // 비밀암호와 약관 사이에 둔다. 오른쪽에 지금 값과 화살표를 함께 보여준다.
        _ImageStyleTile(busy: _busy),
        // 이룸이가 카드를 체크할 때 진동으로 알려줄지. 시안에 없는 줄이라 **임시 시안**이다.
        // 이룸이 휴대폰 설정에도 같은 줄이 있고, 한 휴대폰에 값 하나를 함께 본다.
        const _HapticTile(),
        SettingsTile(
          label: context.l10n.guardianSettingsTerms,
          onTap: _busy
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ConsentDocumentListScreen(),
                  ),
                ),
        ),
        // 앱 버전은 목록의 한 줄로 둔다 — 떨어져 있으면 "앱 정보"로 찾기 어렵다.
        // 제보를 받았을 때 어느 빌드인지 알아야 재현할 수 있다.
        const AppInfoTile(),
        // `문의하기`는 일부러 뺐다. 시안(`1022:4467`)에는 약관과 로그아웃 사이에 있지만
        // 애플이 요구하는 것은 스토어 페이지의 지원 주소이고 앱 안 문의하기는 필수가 아니다.
        // 시안 대조에서 '빠졌다'고 되살리지 않는다. 주소(`AppConfig.supportEmail`)와
        // 글자 토큰(`contactSheetTitle`·`contactSheetEmail`)은 남겨 두었다.
        SettingsTile(
          label: context.l10n.guardianSettingsLogout,
          onTap: _busy ? null : _logout,
        ),
        SettingsTile(
          label: context.l10n.guardianSettingsWithdraw,
          onTap: _busy ? null : _deleteAccount,
          destructive: true,
        ),
        SizedBox(height: space.lg),
      ],
    );
  }
}

/// `이룸이 휴대폰` 줄 (명세 §8-4).
///
/// 연결 전에는 `연결하기`(할 일이 있다), 연결된 뒤에는 `연결됨 ›`(상태를 보여 주고 끊기로 들어간다).
/// **상태를 못 알아도 `연결하기`로 둔다** — 로딩·실패가 설정 화면을 막으면 안 된다. 연결된 보호자가
/// 잘못 `연결하기`를 눌러도 새 암호만 만들어질 뿐 기존 연결은 그대로다(서버가 발급과 끊기를 나눈다).
class _LinkTile extends ConsumerWidget {
  const _LinkTile({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref
        .watch(linkStatusProvider)
        .maybeWhen(
          data: (attempt) => attempt.value?.hasDevice ?? false,
          orElse: () => false,
        );

    return SettingsTile(
      label: connected
          ? context.l10n.guardianSettingsLinkConnected
          : context.l10n.guardianSettingsLinkConnect,
      valueText: connected ? context.l10n.guardianSettingsLinkStatus : null,
      showChevronWithValue: connected,
      onTap: busy
          ? null
          : () async {
              await context.push(
                connected ? Routes.guardianLinkStatus : Routes.linkCode,
              );
              // 돌아오면 그사이 연결·끊기가 있었을 수 있다 — 줄을 다시 맞춘다
              ref.invalidate(linkStatusProvider);
            },
    );
  }
}

/// `이룸이 바꾸기` 줄 — **연결된 이룸이가 둘 이상일 때만** 보인다.
///
/// 이룸이가 하나뿐인 보호자 대부분에게는 고를 것이 없는 줄이다. 회원 정보를 못 받았을 때도
/// 숨긴다 — 이룸이가 몇 명인지 모르면 있는 줄도 없는 줄도 믿을 수 없다.
class _ProfileSwitchTile extends ConsumerWidget {
  const _ProfileSwitchTile({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      memberProvider.select((m) => m.value?.profiles.length ?? 0),
    );
    if (count < 2) return const SizedBox.shrink();
    final active = ref.watch(activeProfileProvider);
    return SettingsTile(
      label: context.l10n.guardianSettingsProfileSwitch,
      // 지금 보는 이룸이 이름을 값으로 보여 준다
      valueText: active?.displayName,
      showChevronWithValue: true,
      onTap: busy ? null : () => context.push(Routes.guardianProfileSwitch),
    );
  }
}

/// `그림 방식` 줄. 오른쪽에 지금 방식(`만화`)을 보여주고 누르면 선택 화면이 열린다.
class _ImageStyleTile extends ConsumerWidget {
  const _ImageStyleTile({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(onboardingProvider.select((p) => p.imageStyle));
    return SettingsTile(
      label: context.l10n.guardianSettingsImageStyle,
      valueText: style.label,
      showChevronWithValue: true,
      onTap: busy ? null : () => context.push(Routes.guardianImageStyle),
    );
  }
}

/// 이룸이 카드 진동 켜기/끄기 줄.
class _HapticTile extends ConsumerWidget {
  const _HapticTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSwitchTile(
      label: context.l10n.guardianSettingsHaptic,
      value: ref.watch(childHapticOnProvider),
      onChanged: (on) => ref.read(childHapticOnProvider.notifier).set(on),
    );
  }
}
