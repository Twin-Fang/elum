import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class ElumApp extends StatelessWidget {
  const ElumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '이룸',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
