import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_info_tile.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/haptics/child_haptics.dart';
import '../../../core/widgets/settings_switch_tile.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../../core/widgets/show_failure.dart';
import '../../auth/presentation/consent_document_list_screen.dart';
import '../application/link_reset.dart';
import '../data/device_link_repository.dart';
import '../../../core/router/pop_or_home.dart';

/// 이룸이 휴대폰의 설정 페이지 (이슈 #363 · #198 19번 · #488).
///
/// 홈 오른쪽 위 톱니를 누르면 열린다. 처음에는 바텀시트였으나(#363) 보호자 설정은 페이지인데 이룸이
/// 설정만 모양이 달랐다. **보호자 설정과 같은 뼈대**(`ElumScaffold` · 뒤로가기와 같은 줄의 제목 ·
/// `SettingsTile` 목록)로 맞췄다 (#488).
///
/// **시안이 없어 보호자 설정 모양을 따랐다** — 디자인 요청 대상이다.
///
/// 항목은 넷이다 — `약관 및 개인정보처리방침` · `앱 정보` · `로그아웃` · `회원탈퇴`. 암호를 묻지 않는다.
/// 보호자 설정의 AI 크레딧·이룸이 휴대폰 연결·임시저장·비밀암호 변경과 일과 만들기·고치기·지우기는 넣지
/// 않는다 (전부 보호자 휴대폰에 있다).
///
/// ## 로그아웃·회원탈퇴는 이 휴대폰의 연결만 끊는다
///
/// 이룸이 휴대폰에는 로그인할 계정이 없다. 그래서 `회원탈퇴`도 보호자 계정·이룸이·일과·별을 지우지
/// **않는다** — 이 휴대폰이 그 이룸이를 더는 보지 않게 연결만 끊는다 (명세 §8-5 "로그아웃이 곧 연결 끊기").
/// 두 줄이 같은 일을 하지만 시안(19번)이 둘을 두고, 사용자가 찾는 말이 달라서 둘 다 둔다. 팝업 문구가 다르다.
///
/// ## 끊기면 로그인 화면으로 간다 (#542)
///
/// 이 휴대폰의 이룸이 표식·역할까지 지우고 로그인 화면으로 보낸다. 예전에는 연결 화면으로 보냈는데, 그 아래에
/// 돌아갈 화면이 없어 뒤로가기로도 앱을 다시 켜도 빠져나올 수 없었다.
///
/// ## 실패하면 머문다
///
/// 서버가 연결을 끊은 **뒤에만** 로컬을 비우고 이동한다. 서버에 닿지 못했으면 이 페이지에 머문 채 에러
/// 코드를 보여준다 — 끊기지도 않았는데 로그인 화면으로 가면 보호자 설정에는 계속 `연결됨`이 남는다.
class ElumiSettingsScreen extends ConsumerStatefulWidget {
  const ElumiSettingsScreen({super.key});

  @override
  ConsumerState<ElumiSettingsScreen> createState() =>
      _ElumiSettingsScreenState();
}

/// 두 줄이 같은 일을 하되 팝업 문구가 갈린다.
enum _Exit {
  logout,
  withdraw;

  // 문구는 값으로 들고 있지 않고 부를 때 읽는다 — 언어가 바뀌어도 굳지 않는다.
  String title(AppLocalizations l10n) => switch (this) {
    logout => l10n.elumiSettingsLogoutTitle,
    withdraw => l10n.elumiSettingsWithdrawTitle,
  };

  String message(AppLocalizations l10n) => switch (this) {
    logout => l10n.elumiSettingsLogoutMessage,
    withdraw => l10n.elumiSettingsWithdrawMessage,
  };

  String failTitle(AppLocalizations l10n) => switch (this) {
    logout => l10n.elumiSettingsLogoutFailTitle,
    withdraw => l10n.elumiSettingsWithdrawFailTitle,
  };
}

class _ElumiSettingsScreenState extends ConsumerState<ElumiSettingsScreen> {
  /// 처리 중 중복 탭 방지 — 같은 요청이 두 번 나가면 두 번째는 404 로 돌아온다.
  bool _busy = false;

  Future<void> _exit(_Exit kind) async {
    // await 뒤에서 context 를 쓰지 않으려고 미리 잡는다
    final l10n = context.l10n;
    final ok = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: kind.title(l10n),
      message: kind.message(l10n),
      actions: [
        ElumDialogAction(
          label: l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: l10n.commonConfirm,
          value: true,
          tone: ElumDialogTone.danger,
        ),
      ],
    );
    if (ok != true || !mounted) return;

    // 연결 암호 화면으로 옮기면 이 화면은 사라진다 — 옮긴 뒤에도 쓸 것을 미리 잡아 둔다.
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context);

    setState(() => _busy = true);
    final failure = await ref
        .read(deviceLinkRepositoryProvider)
        .disconnectThisPhone();
    if (!mounted) return;
    setState(() => _busy = false);

    if (failure != null) {
      // 연결은 그대로다 — 이 페이지에 머물고 이유와 에러 코드를 보여준다.
      await showFailure(
        context,
        failure,
        title: kind.failTitle(l10n),
        fallback: l10n.elumiSettingsExitFailedFallback,
        fallbackCode: 'E-LINK-OUT',
      );
      return;
    }

    // 끊겼다 — 로그인 화면으로 보낸다 (#542). 로그아웃은 로그인 화면으로 가는 것이 기본이고, 이 휴대폰도
    // 소셜 로그인 → 역할 선택 → 연결 순서로 들어왔으므로 같은 길로 다시 들어올 수 있다. 연결 화면으로 보내면
    // 돌아갈 곳이 없어 갇혔다. go 라 스택이 비워져 이 페이지도 닫힌다. 메모리는 이동 뒤에 비운다.
    router.go(Routes.login);
    container.forgetLinkedProfile();
  }

  @override
  Widget build(BuildContext context) {
    return ElumScaffold(
      // 끊는 중에는 뒤로 갈 수 없다 — 결과를 알릴 곳이 없어진다
      onBack: _busy ? null : context.popOrHome,
      // 보호자 설정과 같다: 제목이 뒤로가기와 **같은 줄**에 서고 줄은 x=16 에서 시작한다.
      title: context.l10n.elumiSettingsTitle,
      backTop: 67,
      horizontalPadding: 16,
      // 글자를 키우면 한 화면을 넘을 수 있어 스크롤로 받는다
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 보호자 설정과 같은 자리에서 첫 줄이 시작한다 (뒤로가기 상자 하단에서 28)
            SizedBox(height: 40.h),
            // 읽을거리와 되돌릴 수 없는 동작을 섞지 않는다 — 연결을 끊는 두 줄은 맨 아래다.
            // 순서는 보호자 설정과 같다 (약관 → 앱 정보 → 로그아웃 → 회원탈퇴).
            // 카드를 체크할 때 진동으로 알려줄지 (#515). 보호자 설정과 같은 값을 본다.
            // 시안이 없어 **임시 시안**이다 — 읽을거리 위, 설정값을 맨 앞에 둔다.
            SettingsSwitchTile(
              label: context.l10n.elumiSettingsHapticLabel,
              value: ref.watch(childHapticOnProvider),
              onChanged: (on) =>
                  ref.read(childHapticOnProvider.notifier).set(on),
            ),
            SettingsTile(
              label: context.l10n.elumiSettingsTermsLabel,
              onTap: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ConsentDocumentListScreen(),
                      ),
                    ),
            ),
            const AppInfoTile(),
            SettingsTile(
              label: context.l10n.elumiSettingsLogoutLabel,
              onTap: _busy ? null : () => _exit(_Exit.logout),
            ),
            // 위험색이되 가장 약하게 (docs 5-3). 위 줄과 간격으로 떨어뜨린다.
            SettingsTile(
              label: context.l10n.elumiSettingsWithdrawLabel,
              destructive: true,
              onTap: _busy ? null : () => _exit(_Exit.withdraw),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}
