import 'package:elum/core/layout/adaptive_screen_scale.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트 창 크기를 정한다 (dp 단위 그대로 쓰도록 비율 1.0).
///
/// 비율을 안 고정하면 기본값이 화면비를 2배로 잡아 크기가 틀어진다 (저장소 문서의 함정).
void setTestWindowSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

/// 실제 앱 루트와 같은 구성: AdaptiveScreenScale > MaterialApp(AppTheme)
///
/// [textScale] 로 큰 글자 설정을 흉내 낸다.
Widget adaptiveTestApp({required Widget home, double textScale = 1.0}) {
  return AdaptiveScreenScale(
    baseDesignSize: const Size(393, 852),
    builder: (context, child) => MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
}
