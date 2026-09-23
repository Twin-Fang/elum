import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 화면에 깔린 오로라의 세 색 — Eclipse 시작 · Eclipse 끝 · Planet 시작 (#380).
///
/// 두 원이 시안처럼 **선형 그라데이션**이라 색은 원의 장식에서 읽는다.
/// 원이 한 벌보다 많으면(화면마다 배경을 그리면) 여기서 실패한다.
List<Color> readAuroraColors(WidgetTester tester) {
  LinearGradient gradientOf(Key key) {
    final box = tester.widget<Container>(find.byKey(key, skipOffstage: false));
    return (box.decoration! as BoxDecoration).gradient! as LinearGradient;
  }

  final eclipse = gradientOf(AuroraBackground.eclipseKey);
  final planet = gradientOf(AuroraBackground.planetKey);
  return [eclipse.colors[0], eclipse.colors[1], planet.colors[0]];
}

/// 두 원 묶음이 시안 그룹 윗변(204·244)에서 얼마나 내려와 있는가 — 논리 픽셀.
double readAuroraShift(WidgetTester tester) {
  final t = tester.widget<Transform>(
    find.byKey(AuroraBackground.groupKey, skipOffstage: false),
  );
  return t.transform.getTranslation().y;
}
