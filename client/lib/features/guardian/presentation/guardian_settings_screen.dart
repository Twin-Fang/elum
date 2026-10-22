import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/widgets/app_info_tile.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/haptics/child_haptics.dart';
import '../../../core/sound/child_praise_sound.dart';
import '../../../core/widgets/settings_group.dart';
import '../../../core/widgets/settings_switch_tile.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/presentation/consent_document_list_screen.dart';
import '../../link/data/device_link_repository.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../application/routine_manage_coach_notifier.dart';

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

class _GuardianSettingsScreenState extends ConsumerState<GuardianSettingsScreen>
    with BusyStateMixin<GuardianSettingsScreen> {
  /// 진행 중인 동작을 타일에 구분해 보여주는 key.
  static const _logoutKey = 'logout';
  static const _withdrawKey = 'withdraw';

  /// 뒤로가기 상자 하단(107) > 스크롤 고정 영역 끝(115)
  static const _fixedAreaExtraHeight = 8.0;

  /// 일과관리 칸으로 가서 첫 사용 안내를 다시 띄운다 (요청만 남기면 그 화면이 목록을 받은 뒤 켠다)
  void _replayRoutineManageGuide() {
    ref.read(routineManageCoachProvider.notifier).requestReplay();
    context.go(Routes.guardianManage);
  }

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
    await _run(_logoutKey, () async {
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
    await _run(
      _withdrawKey,
      () => ref.read(authSessionControllerProvider).deleteAccount(),
    );
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
  Future<void> _run(String key, Future<AppFailure?> Function() action) async {
    // 결과가 null(성공)과 구분되도록 레코드로 감싼다. 바깥이 null 이면 진행 중이라 실행하지 않은 것.
    final result = await runBusy(() async => (await action(),), key: key);
    if (result == null || !mounted) return;
    final failure = result.$1;
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
      onBack: context.popOrHome,
      isBackEnabled: !busy,
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
      // 시안의 스크롤 고정 영역은 높이 115 (`스크롤 fix` 1532:7502). 뒤로가기 상자 하단(107)에서 8 더 내려와서
      // 스크롤하는 줄이 제목 줄 아래로 비치지 않는다.
      child: Padding(
        padding: EdgeInsets.only(top: _fixedAreaExtraHeight.h),
        child: SingleChildScrollView(child: _list(space)),
      ),
    );
  }

  /// 설정 메인 시안(`1532:7501`): 크레딧 카드 + 흰 묶음 카드 넷, 묶음 사이 16.
  /// 줄 순서는 시안의 보이는 위치(y)를 따른다 — 연결 / 앱 사용 / 약관 및 정보 / 계정.
  Widget _list(AppSpacing space) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 첫 카드는 y=131 이다. 스크롤 영역이 y=115 에서 시작하므로 16 떨어져 있다.
        SizedBox(height: 16.h),
        // 연결: 이룸이 기기. 이룸이 목록과 바꾸기는 내정보 칸에 있다
        SettingsGroup(
          children: [_LinkTile(busy: busy)],
        ),
        _groupGap,
        // 앱 설정: 암호, 그림 방식, 이룸이 화면 진동과 소리
        SettingsGroup(
          children: [
            SettingsTile(
              isInCard: true,
              label: context.l10n.notificationSettingsTitle,
              onTap: busy
                  ? null
                  : () => context.push(Routes.guardianNotificationSettings),
            ),
            SettingsTile(
              isInCard: true,
              label: context.l10n.guardianSettingsPinChange,
              onTap: busy ? null : () => context.push(Routes.guardianPinChange),
            ),
            _ImageStyleTile(busy: busy),
            const _HapticTile(),
            const _PraiseSoundTile(),
          ],
        ),
        _groupGap,
        // 약관 및 정보 (시안 1532:7501 순서): 사용법 다시 보기 > 약관 > 의견 보내기 > 앱 정보
        SettingsGroup(
          children: [
            SettingsTile(
              isInCard: true,
              label: context.l10n.guardianSettingsRoutineManageGuide,
              onTap: busy ? null : _replayRoutineManageGuide,
            ),
            SettingsTile(
              isInCard: true,
              label: context.l10n.guardianSettingsTerms,
              onTap: busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ConsentDocumentListScreen(),
                      ),
                    ),
            ),
            SettingsTile(
              isInCard: true,
              label: context.l10n.guardianSettingsFeedback,
              onTap: busy ? null : () => context.push(Routes.guardianFeedback),
            ),
            // 앱 버전은 목록의 한 줄로 둔다: 제보를 받았을 때 어느 빌드인지 알아야 재현할 수 있다.
            const AppInfoTile(isInCard: true),
          ],
        ),
        _groupGap,
        // `문의하기`는 일부러 뺐다: 애플이 요구하는 것은 스토어 페이지의 지원 주소이고 앱 안 문의하기는 필수가 아니다.
        // 시안 대조에서 '빠졌다'고 되살리지 않는다 (`AppConfig.supportEmail` 은 남겨 두었다).
        SettingsGroup(
          children: [
            SettingsTile(
              isInCard: true,
              label: context.l10n.guardianSettingsLogout,
              loading: isBusy(_logoutKey),
              onTap: busy ? null : _logout,
            ),
            SettingsTile(
              isInCard: true,
              label: context.l10n.guardianSettingsWithdraw,
              loading: isBusy(_withdrawKey),
              onTap: busy ? null : _deleteAccount,
              destructive: true,
            ),
          ],
        ),
        SizedBox(height: space.lg),
      ],
    );
  }

  /// 묶음 사이 (Figma `1579:8112` gap 16)
  Widget get _groupGap => SizedBox(height: 16.h);
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
      isInCard: true,
      label: connected
          ? context.l10n.guardianSettingsLinkConnected
          : context.l10n.guardianSettingsLinkConnect,
      valueText: connected ? context.l10n.guardianSettingsLinkStatus : null,
      showChevronWithValue: connected,
      onTap: busy
          ? null
          : () async {
              // 열려 있는 동안 캐시가 남아 옛 값이 보인다 — 들어가기 전에 비워 새 값을 받게 한다
              ref.invalidate(linkStatusProvider);
              await context.push(
                connected ? Routes.guardianLinkStatus : Routes.linkCode,
              );
              // 돌아오면 그사이 연결·끊기가 있었을 수 있다 — 줄을 다시 맞춘다
              ref.invalidate(linkStatusProvider);
            },
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
      isInCard: true,
      label: context.l10n.guardianSettingsImageStyle,
      valueText: style.label,
      showChevronWithValue: true,
      onTap: busy ? null : () => context.push(Routes.guardianImageStyle),
    );
  }
}

/// 이룸이 칭찬 소리 켜기/끄기 줄 (#777).
class _PraiseSoundTile extends ConsumerWidget {
  const _PraiseSoundTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSwitchTile(
      isInCard: true,
      label: context.l10n.guardianSettingsPraiseSound,
      value: ref.watch(childPraiseSoundOnProvider),
      onChanged: (on) => ref.read(childPraiseSoundOnProvider.notifier).set(on),
    );
  }
}

/// 이룸이 카드 진동 켜기/끄기 줄.
class _HapticTile extends ConsumerWidget {
  const _HapticTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSwitchTile(
      isInCard: true,
      label: context.l10n.guardianSettingsHaptic,
      value: ref.watch(childHapticOnProvider),
      onChanged: (on) => ref.read(childHapticOnProvider.notifier).set(on),
    );
  }
}
