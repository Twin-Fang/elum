import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/app_status/app_status_gate.dart';
import 'core/app_status/app_status_repository.dart';
import 'core/config/client_tuning.dart';
import 'core/dev/dev_tools_overlay.dart';
import 'core/network/dio_client.dart';
import 'core/network/session_expiry.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/child/application/sync_triggers.dart';
import 'features/link/application/link_reset.dart';
import 'features/link/data/device_link_repository.dart';
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
  );

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
      // 이룸이 휴대폰에는 로그인할 계정이 없다. 로그인 화면으로 보내면
      // 누를 것이 하나도 없는 막다른 길이 된다 (이슈 #206).
      final isElumi = ref.read(localStorageProvider).isElumiDevice;
      if (!isElumi) {
        _router.go(Routes.login);
        return;
      }
      // 이룸이 휴대폰의 세션이 끝났다 = 연결이 끊어졌다 (#363). 보호자가 끊었거나 서버가 이 연결을 더는
      // 인정하지 않는다. 남은 이룸이 정보·일과 캐시를 비워야 다른 이룸이에게 새로 연결해도 이전 것이 보이지
      // 않고, 연결 화면이 `연결이 끊어졌어요`를 말한다 (앱을 껐다 켜도 남는 표식).
      await endElumiLinkAfterSessionLoss(
        repo: ref.read(deviceLinkRepositoryProvider),
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
    return ScreenUtilInit(
      // Figma 프레임 크기(iPhone 16). 이 기준으로 .w/.h/.sp가 계산되므로
      // 화면 코드에서 Figma 좌표를 그대로 쓸 수 있다.
      designSize: const Size(393, 852),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp.router(
        title: '이룸',
        theme: AppTheme.light,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        // 개발자 도구를 모든 화면 위에 얹는다. 화면별 코드는 건드리지 않는다.
        // 플래그가 꺼지면 child를 그대로 반환해 비용이 0이다. (이슈 #13)
        builder: (context, child) => SyncTriggers(
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
      ),
    );
  }
}
