import 'package:elum/core/layout/share_origin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 공유 시트 위치: 아이패드는 시트를 띄울 기준 사각형이 없으면 예외가 난다.
/// 깨지면: 아이패드에서 보호자가 초대 코드를 공유하는 순간 앱이 오류를 낸다.
void main() {
  testWidgets('누른 버튼의 화면 좌표 사각형을 돌려준다', (tester) async {
    BuildContext? buttonContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 40, top: 100),
            child: Builder(
              builder: (context) {
                buttonContext = context;
                return const SizedBox(width: 200, height: 60);
              },
            ),
          ),
        ),
      ),
    );

    final origin = shareOriginOf(buttonContext!);

    expect(origin, const Rect.fromLTWH(40, 100, 200, 60));
  });

  testWidgets('그려지기 전이면 null (예외를 던지지 않는다)', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            // build 도중에는 아직 크기가 없다
            expect(shareOriginOf(c), isNull);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(context, isNotNull);
  });
}
