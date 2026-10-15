import 'package:elum/core/widgets/elum_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

/// 글자 수 제한은 UTF-16 코드 단위가 아니라 **사용자가 보는 글자(grapheme)** 로 센다.
/// 이모지 한 개가 코드 단위 둘 이상이라 코드 단위로 세면 일본어·중국어·이모지 이름이 잘린다.
/// 지금 `LengthLimitingTextInputFormatter` 가 이미 그렇게 동작한다 — 바뀌지 않게 고정한다.
void main() {
  useFigmaViewport();

  Future<String> typed(WidgetTester tester, String input, int max) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpWithLocale(
      tester,
      Scaffold(
        body: ElumTextField(hintText: 'name', controller: controller, maxLength: max),
      ),
    );
    await tester.enterText(find.byType(TextField), input);
    await tester.pump();
    return controller.text;
  }

  testWidgets('이모지(가족 ZWJ 시퀀스) 한 개는 한 글자로 센다 — 코드 단위 8개', (tester) async {
    const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
    expect(family.length, 8); // 코드 단위로 세면 3글자 제한에 걸린다
    expect(await typed(tester, '$family$family$family$family가', 3), '$family$family$family');
  });

  testWidgets('결합 문자(e + 결합 악센트)는 한 글자다', (tester) async {
    const e = 'e\u0301';
    expect(e.length, 2);
    expect(await typed(tester, '$e$e$e$e', 3), '$e$e$e');
  });

  testWidgets('한글 완성형은 한 글자, 자모 조합(NFD)도 한 글자다', (tester) async {
    expect(await typed(tester, '가나다라마', 3), '가나다');
    // ㄱ+ㅏ 조합용 자모 두 개 = 보이는 글자 하나
    const nfd = '\u1100\u1161';
    expect(nfd.length, 2);
    expect(await typed(tester, '$nfd$nfd$nfd$nfd', 3), '$nfd$nfd$nfd');
  });

}
