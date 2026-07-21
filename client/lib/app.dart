import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/application/onboarding_notifier.dart';

class ElumApp extends ConsumerStatefulWidget {
  const ElumApp({super.key});

  @override
  ConsumerState<ElumApp> createState() => _ElumAppState();
}

class _ElumAppState extends ConsumerState<ElumApp> {
  // 라우터는 앱 수명 동안 하나만 유지한다.
  // build마다 새로 만들면 화면 전환 시 스택이 초기화된다.
  late final _router = createRouter(
    // 온보딩 미완료 상태로 보호자·아동 화면에 들어오는 것을 막는다
    isOnboardingCompleted: () =>
        ref.read(localStorageProvider).isOnboardingCompleted,
  );

  @override
  Widget build(BuildContext context) {
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
      ),
    );
  }
}
