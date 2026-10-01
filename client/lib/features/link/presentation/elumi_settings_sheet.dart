import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_info_tile.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../../core/widgets/show_failure.dart';
import '../../auth/presentation/consent_document_list_screen.dart';
import '../application/link_reset.dart';
import '../data/device_link_repository.dart';

/// 이룸이 휴대폰의 설정 시트 (이슈 #363 · #198 19번).
///
/// **시안이 없어 임시 배치다** — 기존 설정 줄(`SettingsTile`)과 사진 출처 시트의 모양을 빌렸다.
/// 디자인 요청 대상이다.
///
/// 항목은 **둘뿐이다 — `로그아웃` · `회원탈퇴`.** 암호를 묻지 않는다. 일과 만들기·고치기·지우기는 넣지
/// 않는다 (전부 보호자 휴대폰에 있다).
///
/// ## 둘 다 이 휴대폰의 연결만 끊는다
///
/// 이룸이 휴대폰에는 로그인할 계정이 없다. 그래서 `회원탈퇴`도 보호자 계정·이룸이·일과·별을 지우지
/// **않는다** — 이 휴대폰이 그 이룸이를 더는 보지 않게 연결만 끊는다 (명세 §8-5 "로그아웃이 곧 연결 끊기").
/// 두 줄이 같은 일을 하지만 시안(19번)이 둘을 두고, 사용자가 찾는 말이 달라서 둘 다 둔다. 팝업 문구가 다르다.
///
/// ## 실패하면 머문다
///
/// 서버가 연결을 끊은 **뒤에만** 로컬을 비우고 이동한다. 서버에 닿지 못했으면 시트에 머문 채 에러 코드를
/// 보여준다 — 끊기지도 않았는데 연결 화면으로 가면 보호자 설정에는 계속 `연결됨`이 남는다.
class ElumiSettingsSheet extends ConsumerStatefulWidget {
  const ElumiSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.colors.sheetScrim,
      builder: (_) => const ElumiSettingsSheet(),
    );
  }

  @override
  ConsumerState<ElumiSettingsSheet> createState() => _ElumiSettingsSheetState();
}

/// 시트의 두 줄이 같은 일을 하되 팝업 문구가 갈린다.
enum _Exit {
  logout(
    title: '로그아웃 하실건가요?',
    message: '이 휴대폰의 연결이 끊어져요\n다시 쓰려면 보호자에게\n연결 암호를 받아야 해요',
    failTitle: '로그아웃하지 못했어요',
  ),
  withdraw(
    title: '회원탈퇴 하실건가요?',
    message: '이 휴대폰의 연결만 끊어져요\n일과와 별은 보호자 휴대폰에\n그대로 남아요',
    failTitle: '탈퇴하지 못했어요',
  );

  const _Exit({
    required this.title,
    required this.message,
    required this.failTitle,
  });

  final String title;
  final String message;
  final String failTitle;
}

class _ElumiSettingsSheetState extends ConsumerState<ElumiSettingsSheet> {
  /// 처리 중 중복 탭 방지 — 같은 요청이 두 번 나가면 두 번째는 404 로 돌아온다.
  bool _busy = false;

  Future<void> _exit(_Exit kind) async {
    final ok = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: kind.title,
      message: kind.message,
      actions: const [
        ElumDialogAction(
          label: '취소',
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(label: '확인', value: true, tone: ElumDialogTone.danger),
      ],
    );
    if (ok != true || !mounted) return;

    // 시트가 닫힌 뒤에도 쓸 것을 미리 잡아 둔다 — 아래에서 시트를 먼저 닫는다.
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context);

    setState(() => _busy = true);
    final failure = await ref
        .read(deviceLinkRepositoryProvider)
        .disconnectThisPhone();
    if (!mounted) return;
    setState(() => _busy = false);

    if (failure != null) {
      // 연결은 그대로다 — 시트에 머물고 이유와 에러 코드를 보여준다.
      await showFailure(
        context,
        failure,
        title: kind.failTitle,
        fallback: '잠시 후 다시 시도해주세요',
        fallbackCode: 'E-LINK-OUT',
      );
      return;
    }

    // 끊겼다 — 시트를 닫고 연결 암호 넣기로 보낸다 (#206 흐름). 메모리는 이동 뒤에 비운다.
    navigator.pop();
    goToLinkEnter(router);
    container.forgetLinkedProfile();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return PopScope(
      // 끊는 중에 시트를 닫으면 결과를 알릴 곳이 없다
      canPop: !_busy,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SafeArea(
          top: false,
          // 글자를 키우면 시트가 화면을 넘을 수 있어 스크롤로 받는다
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 14.h),
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colors.sheetHandle,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Text(
                    '설정',
                    style: typo.subtitle.copyWith(color: colors.textPrimary),
                  ),
                ),
                SizedBox(height: 8.h),
                // 읽을거리와 되돌릴 수 없는 동작을 섞지 않는다 — 계정을 끊는 두 줄은 맨 아래다.
                // 순서는 보호자 설정과 같다 (약관 → 앱 정보 → 로그아웃 → 회원탈퇴).
                SettingsTile(
                  label: '약관 및 개인정보처리방침',
                  // 시트 위에 화면을 올린다 — 돌아오면 시트가 그대로 있다
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
                  label: '로그아웃',
                  onTap: _busy ? null : () => _exit(_Exit.logout),
                ),
                // 위험색이되 가장 약하게 (docs 5-3). 위 줄과 간격으로 떨어뜨린다.
                SettingsTile(
                  label: '회원탈퇴',
                  destructive: true,
                  onTap: _busy ? null : () => _exit(_Exit.withdraw),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
