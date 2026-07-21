import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class ElumApp extends StatefulWidget {
  const ElumApp({super.key});

  @override
  State<ElumApp> createState() => _ElumAppState();
}

class _ElumAppState extends State<ElumApp> {
  // 라우터는 앱 수명 동안 하나만 유지한다.
  // build마다 새로 만들면 화면 전환 시 스택이 초기화된다.
  late final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '이룸',
      theme: AppTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
