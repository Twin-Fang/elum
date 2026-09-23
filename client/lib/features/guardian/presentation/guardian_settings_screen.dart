import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/elum_dialog.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../core/app_status/app_status_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/consent_document_list_screen.dart';

/// 보호자 설정 화면 (이슈 #181).
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
    // 모양으로 하게 된다 — 일과 삭제는 팝업, 로그아웃은 시트였다 (#353).
    final ok = await showElumDialog<bool>(
      context: context,
      // **한 단계 낮춰 쓴다.** 시안은 로그아웃과 회원탈퇴를 한 변형으로 묶어
      // 둘 다 붉게 칠하지만, 로그아웃은 다시 들어오면 그대로다. 둘을 같은
      // 빨강으로 두면 진짜 되돌릴 수 없는 쪽과 구분이 사라진다 (#188 의 판단을
      // 유지한다). 색과 아이콘만 낮추고 **모양은 시안 팝업 그대로다** (#353).
      icon: ElumDialogIcon.warning,
      title: '로그아웃 하실건가요?',
      actions: const [
        ElumDialogAction(label: '취소', value: false, tone: ElumDialogTone.neutral),
        ElumDialogAction(label: '확인', value: true, tone: ElumDialogTone.primary),
      ],
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(authRepositoryProvider).logout();
      // 로그아웃은 이 기기에서 나가는 것이 본질이라 서버가 실패해도 목적은 달성된다.
      return null;
    });
  }

  /// 문의 주소를 보여주고 복사하게 한다 (Figma `설정_문의하기` 1045:5005).
  ///
  /// **메일 앱을 바로 열지 않는다.** 메일 계정이 없는 기기에서는 아무 일도 일어나지
  /// 않아 사용자는 눌렸는지조차 모른다. 주소를 눈에 보이게 두고 복사하게 하면
  /// 어떤 기기에서도 다음 행동이 있다.
  ///
  /// 이 줄은 한 번 지웠다가(`c535ca7` — 스토어 지원 주소로 갈음된다고 봤다)
  /// 새 시안에 다시 그려져 되살렸다.
  Future<void> _contact() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ContactSheet(),
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: '회원탈퇴 하실건가요?',
      // **설명 한 줄은 시안에 없지만 남긴다.** 시안은 로그아웃과 회원탈퇴를 한
      // 변형으로 묶어 제목만 두는데, 둘은 결정적으로 다르다 — 로그아웃은
      // 다시 들어오면 그대로지만 탈퇴는 되돌아오지 않는다. 되돌릴 수 없다는
      // 고지를 빼면 사용자가 잃는 것이 크다 (docs 예외처리 규칙 · #187).
      // 팝업 컴포넌트는 두 줄 제목을 이미 담는다(`로그인실패` 변형이 그렇다).
      message: '만든 일과와 모은 별이 모두 사라져요\n다시 로그인해도 되돌릴 수 없어요',
      actions: const [
        ElumDialogAction(label: '취소', value: false, tone: ElumDialogTone.neutral),
        ElumDialogAction(label: '확인', value: true, tone: ElumDialogTone.danger),
      ],
    );
    if (ok != true) return;
    await _run(() => ref.read(authRepositoryProvider).deleteAccount());
  }

  /// 되돌릴 수 없다고 안내한 동작이 실패했을 때.
  ///
  /// 화면을 옮기지 않는다 — 계정은 서버에 그대로 있고 토큰도 살아 있으므로
  /// 이 자리에서 다시 누르면 된다. 코드(E-DEL)를 같이 보여줘야 제보를 받았을 때
  /// 어디서 멈췄는지 알 수 있다.
  void _tellFailed(AppFailure? failure) {
    // 서버가 이유를 알려줬으면 그 문구가 아래 기본 문구를 이긴다 (#352).
    showFailureSnack(
      context,
      failure,
      fallback: '탈퇴하지 못했어요. 잠시 후 다시 해주세요',
      fallbackCode: 'E-DEL',
    );
  }

  /// 계정 정리 동작의 공통 뼈대.
  ///
  /// 동작이 **실제로 됐는지**를 받아 분기한다. 됐으면 로컬이 비었으니 이 화면에
  /// 남을 수 없어 로그인으로 보내고, 안 됐으면 바뀐 것이 없으니 이 자리에 머문
  /// 채로 알린다 (이슈 #187).
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
      context.go(Routes.login);
    } else {
      _tellFailed(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return ElumScaffold(
      onBack: _busy ? null : () => context.pop(),
      // 시안(`1022:4467`)은 제목이 뒤로가기와 **같은 줄**에 선다. 본문에 두면
      // 뒤로가기 아래로 내려간다 (#349).
      title: '설정',
      // 줄이 x=16 에서 시작한다. 뼈대 기본 여백(24)이면 8 만큼 안쪽으로 밀린다.
      backTop: 67,
      horizontalPadding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 시안 첫 줄은 y=147 이다. 뒤로가기 상자 하단(119)에서 28 떨어져 있다.
          SizedBox(height: 40.h),
          SettingsTile(
            label: '이룸이 휴대폰 연결하기',
            onTap: _busy ? null : () => context.push(Routes.linkCode),
          ),
          // 계정을 정리하는 항목(로그아웃·탈퇴) 위에 둔다. 읽을거리와 되돌릴 수 없는
          // 동작이 섞이면 실수로 누르기 쉽다.
          SettingsTile(

            label: '임시저장',

            onTap: _busy ? null : () => context.push(Routes.guardianDrafts),

          ),
          SettingsTile(
            label: '약관 및 개인정보처리방침',
            onTap: _busy
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ConsentDocumentListScreen(),
                      ),
                    ),
          ),
          SettingsTile(

            label: '문의하기',

            onTap: _busy ? null : _contact,

          ),
          SettingsTile(
            label: '로그아웃',
            onTap: _busy ? null : _logout,
          ),
          SettingsTile(
            label: '회원탈퇴',
            onTap: _busy ? null : _deleteAccount,
            destructive: true,
          ),
          // 게시된 도움말 페이지가 "앱 버전 — 설정 화면 맨 아래"라고 안내한다.
          // 제보를 받았을 때 어느 빌드인지 알아야 재현할 수 있다 (이슈 #289).
          const Spacer(),
          const _VersionLine(),
          SizedBox(height: space.lg),
        ],
      ),
    );
  }
}

/// 설정 맨 아래 버전 줄. 읽지 못하면 아무것도 그리지 않는다.
///
/// 버전을 못 읽는 것(플러그인 미등록·테스트 환경)은 사용자가 할 수 있는 일이
/// 없으므로 오류로 보여줄 이유가 없다. 그 자리는 그냥 비워 둔다.
class _VersionLine extends ConsumerWidget {
  const _VersionLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).maybeWhen(
          data: (value) => value,
          orElse: () => '',
        );
    if (version.isEmpty) return const SizedBox.shrink();

    return Text(
      '버전 $version',
      textAlign: TextAlign.center,
      style: context.typo.caption.copyWith(
        color: context.colors.textPlaceholder,
      ),
    );
  }
}

/// 되돌릴 수 없는 동작을 한 번 확인받는 시트.
///
/// 카드 수정 시트와 같은 바텀시트 방식을 쓴다 — 확인 창만 다른 형태로 뜨면
/// 앱 안에서 두 가지 문법을 배우게 된다.
class _ContactSheet extends StatelessWidget {
  const _ContactSheet();

  static const _height = 375.0;
  static const _radius = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final email = AppConfig.supportEmail;

    return Container(
      height: _height.h,
      // 자식이 배경을 깔아 둥근 모서리를 덮지 않게 자른다 (#345에서 겪은 것).
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_radius.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 손잡이 — 시안 y=492, 시트 상단(476)에서 16.
          SizedBox(height: 16.h),
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
          // 제목 y=516 → 손잡이(496)에서 20.
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              '문의하기',
              style: context.typo.contactSheetTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          // 안내 y=560 → 제목 하단(536)에서 24.
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              '평일 기준 2~3일 안에 답장드려요',
              style: context.typo.settingsTileLabel.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          // 주소 칸 y=600 → 안내 하단(576)에서 24.
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              height: 68.h,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              decoration: BoxDecoration(
                color: colors.editChipBg,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.contactSheetEmail.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const Spacer(),
          // 버튼 y=730, 하단 796 → 시트 하단(851)까지 55.
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 55.h),
            child: ElumButton(
              label: '메일 복사하기',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: email));
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('문의 주소를 복사했어요')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
