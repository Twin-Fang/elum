import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_banner_slot.dart';
import '../../../core/ads/ad_ids.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../core/app_status/app_status_repository.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/consent_document_list_screen.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import 'pictogram_credit_screen.dart';
import 'widgets/ai_credit_card.dart';

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
      // 시안 그대로 붉게 칠한다. 예전에는 로그아웃을 한 단계 낮춰 노랑으로
      // 칠했는데(#188 · #353), 시안에 노란 변형이 없어 #433 에서 되돌렸다.
      // 되돌릴 수 없는 탈퇴와는 설명 문장 유무로 구분된다.
      icon: ElumDialogIcon.alert,
      title: '로그아웃 하실건가요?',
      actions: const [
        ElumDialogAction(label: '취소', value: false, tone: ElumDialogTone.neutral),
        ElumDialogAction(label: '확인', value: true, tone: ElumDialogTone.danger),
      ],
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(authRepositoryProvider).logout();
      // 로그아웃은 이 기기에서 나가는 것이 본질이라 서버가 실패해도 목적은 달성된다.
      return null;
    });
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
    showFailure(
      context,
      failure,
      title: '탈퇴하지 못했어요',
      fallback: '잠시 후 다시 시도해주세요',
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
      // 하단 배너(#281). 로드 전·실패 시 높이 0이라 자리를 남기지 않는다.
      bottomBanner: const AdBannerSlot(placement: AdPlacement.bannerSettings),
      // 크레딧 카드(#407)가 들어와 글꼴을 키우면 한 화면을 넘는다 — 스크롤로 끝까지
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
        // 이번 주 AI 생성 (#407). 제목 아래·첫 줄 위 — 꺼져 있으면 자리도 없다.
        const AiCreditCard(),
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
        // 시안(`1022:4467`) 자리 그대로 — 임시저장과 약관 사이 (#437).
        SettingsTile(
          label: '비밀암호 변경하기',
          onTap: _busy ? null : () => context.push(Routes.guardianPinChange),
        ),
        // 카드 그림을 어떤 방식으로 만들지 (#458). 시안(`1022:4467`)에 없는 줄이라
        // **임시 시안**이다 — 시안 줄 순서(연결·임시저장·비밀암호·약관)를 깨지 않게
        // 비밀암호와 약관 사이에 둔다. 오른쪽에 지금 값과 화살표를 함께 보여준다.
        _ImageStyleTile(busy: _busy),
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
        // 카드 그림에 쓰는 무료 픽토그램(Mulberry Symbols, CC BY-SA 4.0)의 저작자 표기 (#469).
        // 약관 옆 읽을거리 묶음에 둔다. 시안에 없는 줄이라 **임시 시안**이다(디자인 요청 #459).
        SettingsTile(
          label: '그림 출처',
          onTap: _busy
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PictogramCreditScreen(),
                  ),
                ),
        ),
        // 앱 버전은 **목록의 한 줄**로 둔다 (#418). 예전에는 화면 맨 아래 가운데
        // 글자였는데(#289) 목록과 떨어져 있어 "앱 정보"로 찾기 어려웠다.
        // 제보를 받았을 때 어느 빌드인지 알아야 재현할 수 있다.
        const _AppInfoTile(),
        // `문의하기`는 **일부러 뺐다** (#312, 2026-09-23 결정).
        // 시안(`1022:4467`)에는 이 자리(약관과 로그아웃 사이)에 그려져 있지만
        // App Store 심사 기간에는 두지 않는다 — 애플이 요구하는 것은 스토어
        // 페이지의 지원 주소이고, 앱 안 문의하기는 필수가 아니다.
        // **시안 대조에서 '빠졌다'고 되살리지 않는다** (#349 에서 한 번 그랬다).
        // 심사나 운영에서 문제가 되면 되살린다 — 누르면 뜨던 시트(`1045:5005`)는
        // `ce1271d` 에 있고, 주소(`AppConfig.supportEmail`)와 글자 토큰
        // (`contactSheetTitle`·`contactSheetEmail`)은 그대로 남겨 두었다.
        SettingsTile(label: '로그아웃', onTap: _busy ? null : _logout),
        SettingsTile(
          label: '회원탈퇴',
          onTap: _busy ? null : _deleteAccount,
          destructive: true,
        ),
        SizedBox(height: space.lg),
      ],
    );
  }
}

/// `그림 방식` 줄. 오른쪽에 지금 방식(`만화`)을 보여주고 누르면 선택 화면이 열린다 (#458).
class _ImageStyleTile extends ConsumerWidget {
  const _ImageStyleTile({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(onboardingProvider.select((p) => p.imageStyle));
    return SettingsTile(
      label: '그림 방식',
      valueText: style.label,
      showChevronWithValue: true,
      onTap: busy ? null : () => context.push(Routes.guardianImageStyle),
    );
  }
}

/// `앱 정보` 줄. 오른쪽에 `v1.44.0` 처럼 앱 버전을 보여주고, 누를 수는 없다.
///
/// 버전을 못 읽으면(플러그인 미등록·테스트 환경) 값 자리만 비운다. 사용자가 할 수
/// 있는 일이 없으므로 오류로 보여줄 이유가 없고, 줄은 남겨 자리가 흔들리지 않게 한다.
class _AppInfoTile extends ConsumerWidget {
  const _AppInfoTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref
        .watch(appVersionProvider)
        .maybeWhen(data: (value) => value, orElse: () => '');

    return SettingsTile(
      label: '앱 정보',
      onTap: null,
      valueText: version.isEmpty ? '' : 'v$version',
    );
  }
}
