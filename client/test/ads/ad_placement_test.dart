import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp(theme: AppTheme.light, home: child),
      );

  testWidgets('bottomBanner는 본문 아래 맨 끝에 놓이고 본문과 겹치지 않는다', (tester) async {
    await tester.pumpWidget(host(ElumScaffold(
      onBack: () {},
      bottomBanner: const SizedBox(key: Key('배너'), height: 60),
      child: const Align(
        alignment: Alignment.bottomCenter,
        child: Text('본문 맨 아래', key: Key('본문')),
      ),
    )));
    final banner = tester.getRect(find.byKey(const Key('배너')));
    final body = tester.getRect(find.byKey(const Key('본문')));
    expect(body.bottom, lessThanOrEqualTo(banner.top));
  });

  test('bottomButton과 bottomBanner를 함께 쓰면 assert로 막는다', () {
    expect(
      () => ElumScaffold(
        bottomButton: const SizedBox(),
        bottomBanner: const SizedBox(),
        child: const SizedBox(),
      ),
      throwsAssertionError,
    );
  });

  test('belowButton과 bottomBanner도 함께 쓰지 못한다', () {
    expect(
      () => ElumScaffold(
        belowButton: const SizedBox(),
        bottomBanner: const SizedBox(),
        child: const SizedBox(),
      ),
      throwsAssertionError,
    );
  });
}
