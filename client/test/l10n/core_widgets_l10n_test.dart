import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/core/widgets/elum_error_view.dart';
import 'package:elum/core/widgets/show_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

/// 공용 위젯이 ARB 를 읽는다 — ko 에서는 옛 문구 그대로, 번역이 비어 있는 언어는 ko 로 떨어진다.
void main() {
  useFigmaViewport();
  testWidgets('에러 줄인 화면 — 코드가 있으면 다시 시도 (코드)', (tester) async {
    await pumpWithLocale(
      tester,
      Scaffold(
        body: ElumErrorView(
          message: '일과를 불러오지 못했어요',
          errorCode: 'E-RT-001',
          onRetry: () {},
          compact: true,
        ),
      ),
    );
    expect(find.text('다시 시도 (E-RT-001)'), findsOneWidget);
  });

  testWidgets('에러 화면 — 버튼 문구와 설명 기본 안내', (tester) async {
    await pumpWithLocale(
      tester,
      Scaffold(
        body: ElumErrorView(message: '실패', onRetry: () {}),
      ),
    );
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('팝업 — 버튼을 안 넘기면 확인 하나, 배경 막 이름은 팝업 닫기', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithLocale(
      tester,
      const Scaffold(body: ElumDialogCard<void>(title: '제목')),
    );
    expect(find.text('확인'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('실패 팝업 — 제목에 마침표를 붙이고 확인 버튼을 단다', (tester) async {
    late BuildContext ctx;
    await pumpWithLocale(
      tester,
      Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox();
        },
      ),
    );
    showFailure(
      ctx,
      Exception('x'),
      title: '로그인하지 못했어요',
      fallback: '잠시 후 다시 시도해주세요',
      fallbackCode: 'E-TEST',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('로그인하지 못했어요.\n잠시 후 다시 시도해주세요'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
  });

  testWidgets('번역이 비어 있는 언어(en)는 ko 문구로 떨어진다', (tester) async {
    await pumpWithLocale(
      tester,
      Scaffold(
        body: ElumErrorView(
          message: 'm',
          errorCode: 'E-1',
          onRetry: () {},
          compact: true,
        ),
      ),
      locale: const Locale('en'),
    );
    expect(find.text('다시 시도 (E-1)'), findsOneWidget);
  });
}
