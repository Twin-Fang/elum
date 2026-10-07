import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/ads/ad_consent.dart';
import 'core/app_status/app_status_gate.dart';
import 'core/app_status/app_status_repository.dart';
import 'core/config/client_tuning.dart';
import 'core/dev/dev_locale_override.dart';
import 'core/dev/dev_tools_overlay.dart';
import 'core/l10n/app_l10n.dart';
import 'core/l10n/current_l10n.dart';
import 'core/network/dio_client.dart';
import 'core/network/session_expiry.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/elum_toast.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/child/application/sync_triggers.dart';
import 'features/link/application/link_reset.dart';
import 'features/onboarding/application/onboarding_notifier.dart';
import 'features/profile/application/invite_inbox.dart';
import 'features/profile/application/invite_link_intake.dart';
import 'features/profile/presentation/invite_link_host.dart';

class ElumApp extends ConsumerStatefulWidget {
  const ElumApp({super.key});

  @override
  ConsumerState<ElumApp> createState() => _ElumAppState();
}

class _ElumAppState extends ConsumerState<ElumApp> {
  // 라우터는 앱 수명 동안 하나만 유지한다.
  // build마다 새로 만들면 화면 전환 시 스택이 초기화된다.
  late final GoRouter _router = createRouter(
    // 온보딩 미완료 상태로 보호자·아동 화면에 들어오는 것을 막는다
    isOnboardingCompleted: () =>
        ref.read(localStorageProvider).isOnboardingCompleted,
    // 세션이 없으면 로그인 화면으로 되돌린다 — 로그아웃·회원삭제 후 재진입을 막는다
    hasToken: () => ref.read(authRepositoryProvider).hasSession,
    // 이룸이 휴대폰은 로그인이 아니라 연결로 붙는다 (이슈 #206)
    isElumiDevice: () => ref.read(localStorageProvider).isElumiDevice,
    // 역할을 고르기 전에는 보호자·이룸이 어느 쪽 화면도 열지 않는다 (이슈 #212)
    hasRole: () => ref.read(localStorageProvider).selectedRole != null,
    // 앱이 꺼져 있다 초대 링크로 열릴 때 (#365). 켜져 있을 때는 아래 InviteLinkHost 가 먼저 받는다.
    onInviteLink: (link) => _inviteIntake.accept(link),
  );

  // 초대 링크를 알맞은 때에 입력 화면으로 이어 준다 (#365).
  late final InviteLinkIntake _inviteIntake = InviteLinkIntake(
    inbox: ref.read(inviteInboxProvider),
    isElumiDevice: () => ref.read(localStorageProvider).isElumiDevice,
    hasSession: () => ref.read(authRepositoryProvider).hasSession,
    // 위에 쌓은 화면까지 센 맨 위 화면 — 설정 하위 화면 위에 입력 화면을 얹지 않는다
    topLocation: () =>
        _router.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation,
    open: () => _router.push(Routes.inviteEnter),
    // 앱이 꺼져 있다 열린 링크는 첫 화면이 그려지기 전일 수 있어 다음 프레임에 띄운다
    onElumiDeviceRejected: () => WidgetsBinding.instance.addPostFrameCallback(
      (_) => showElumToastOn(
        _messengerKey.currentState,
        appL10n.inviteRejectedOnElumiDevice,
      ),
    ),
  );

  /// 컨텍스트 없이 토스트를 띄우기 위한 키 — 초대 링크는 화면 밖에서 들어온다.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// 보호자 휴대폰이 지금 어느 화면에 있는지 남긴다 (#532).
  ///
  /// 이룸이 화면으로 가는 길이 여럿이라(보호자 홈 버튼·일과 완료 뒤 등) 화면마다 저장하면
  /// 하나를 빠뜨리기 쉽다. 라우터가 옮길 때마다 여기 한 곳에서 본다.
  void _rememberScreen() {
    final storage = ref.read(localStorageProvider);
    // 이룸이 전용 휴대폰은 늘 이룸이 화면이다 — 따로 기억할 것이 없다
    if (storage.isElumiDevice) return;
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    final bool onElumi;
    if (path == Routes.child || path.startsWith('${Routes.child}/')) {
      onElumi = true;
    } else if (path == Routes.guardian ||
        path.startsWith('${Routes.guardian}/')) {
      onElumi = false;
    } else {
      // 모드 전환·설정 밖 화면은 어느 쪽도 아니다. 마지막 값을 그대로 둔다.
      return;
    }
    storage.setResumeOnElumiScreen(onElumi).catchError((Object e) {
      // 저장에 실패해도 화면은 그대로 쓸 수 있다. 다음에 켤 때 보호자 홈이 열릴 뿐이다.
      debugPrint('[E-SCREEN-SAVE] 마지막 화면 저장 실패: $e');
    });
  }

  @override
  void initState() {
    super.initState();
    _router.routerDelegate.addListener(_rememberScreen);
    // 추적 허용(ATT)은 광고 요청이 아니라 앱을 열자마자 묻는다. 광고가 안 뜨는 경로로 쓰는
    // 사람도 팝업을 보게 하려는 것이다(#519 심사 2.1). 첫 프레임을 그린 뒤 불러야 팝업이 뜬다.
    // 이룸이 전용 휴대폰은 광고를 보여 주지 않으므로 묻지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(localStorageProvider).isElumiDevice) return;
      AdConsent.requestOnLaunch();
    });
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_rememberScreen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 세션이 끝나면 로그인으로 되돌린다.
    //
    // 라우터 가드는 **화면을 옮길 때**만 평가된다. 홈에 머무는 중에 토큰이 만료되면
    // 가드가 다시 불리지 않아, 서버 요청은 전부 401인데 화면은 캐시로 정상처럼
    // 남아 있었다 (이슈 #175). 그래서 신호를 듣고 여기서 직접 옮긴다.
    // 서버가 준 대기·연출 시간값을 받자마자 적용하고 다음 실행을 위해 저장한다.
    // 관리자 화면에서 고친 값이 앱을 다시 올리지 않아도 반영된다.
    ref.listen(appStatusProvider, (previous, next) {
      final tuning = next.value?.status.tuning;
      if (tuning == null) return;
      applyServerTuning(
        tuning,
        dio: ref.read(dioProvider),
        storage: ref.read(localStorageProvider),
      );
    });

    ref.listen<int>(sessionExpiryProvider, (previous, next) async {
      if (previous == null || next <= previous) return;
      await handleSessionExpired(
        router: _router,
        container: ProviderScope.containerOf(context),
      );
    });

    // 켜져 있는 앱에 들어오는 초대 링크를 라우터보다 먼저 받는다 — MaterialApp.router 위에 둔다.
    return InviteLinkHost(
      router: _router,
      intake: _inviteIntake,
      child: _buildApp(),
    );
  }

  Widget _buildApp() {
    // 언어 관련 인자는 AppL10n 한 곳에서 만든다 — 개발자 도구 강제 언어의 게이트도 거기서 건다.
    final l10n = AppL10n.routerArgs(
      forcedLocale: ref.watch(devLocaleOverrideProvider),
      inner: (context, child) => SyncTriggers(
        // 동기화 트리거는 라우터·오버레이와 무관하므로 가장 바깥에 둔다 (이슈 #140)
        child: AppStatusGate(
          // 점검 중이거나 너무 낮은 버전이면 여기서 화면을 대신 그린다 (이슈 #279).
          // 확인하지 못하면 그대로 통과시키므로 평소에는 비용이 없다.
          child: DevToolsOverlay(
            // 오버레이는 GoRouter보다 위에 있어 context로 라우터를 찾지 못한다.
            // 라우터를 들고 있는 여기서 이동 방법을 넘겨준다.
            onNavigate: _router.go,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );

    return ScreenUtilInit(
      // Figma 프레임 크기(iPhone 16). 이 기준으로 .w/.h/.sp가 계산되므로
      // 화면 코드에서 Figma 좌표를 그대로 쓸 수 있다.
      designSize: const Size(393, 852),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp.router(
        onGenerateTitle: l10n.onGenerateTitle,
        theme: AppTheme.light,
        locale: l10n.locale,
        supportedLocales: l10n.supportedLocales,
        localizationsDelegates: l10n.localizationsDelegates,
        localeListResolutionCallback: l10n.localeListResolutionCallback,
        routerConfig: _router,
        scaffoldMessengerKey: _messengerKey,
        debugShowCheckedModeBanner: false,
        // 개발자 도구를 모든 화면 위에 얹는다. 화면별 코드는 건드리지 않는다. (이슈 #13)
        builder: l10n.builder,
      ),
    );
  }
}
