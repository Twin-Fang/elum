import 'package:elum/core/widgets/elum_state_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 본문 전체 상태(로딩·빈 상태·실패)는 남는 영역의 세로 가운데에 같은 자리로 놓인다.
void main() {
  Widget host(Widget body, {double height = 400}) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 300, height: height, child: body),
      ),
    ),
  );

  testWidgets('남는 높이의 세로 가운데에 놓는다', (tester) async {
    await tester.pumpWidget(
      host(
        const ElumStateBody(
          child: SizedBox(key: Key('c'), width: 50, height: 40),
        ),
      ),
    );
    expect(tester.getCenter(find.byKey(const Key('c'))).dy, 200);
  });

  testWidgets('로딩도 같은 자리에 놓는다', (tester) async {
    await tester.pumpWidget(host(const ElumStateBody.loading()));
    expect(tester.getCenter(find.byType(CircularProgressIndicator)).dy, 200);
  });

  testWidgets('내용이 높이보다 크면 잘리지 않고 스크롤된다', (tester) async {
    await tester.pumpWidget(
      host(
        const ElumStateBody(
          child: SizedBox(key: Key('big'), width: 50, height: 900),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsOneWidget);
    await tester.drag(find.byType(Scrollable), const Offset(0, -300));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('big'))).dy, lessThan(0));
  });

  testWidgets('높이를 모르는 자리(바깥 스크롤)에서도 예외 없이 그린다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ElumStateBody(child: Text('실패'))),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('실패'), findsOneWidget);
  });
}
