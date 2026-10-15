import 'package:elum/core/widgets/show_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// 제목과 할 일을 한 문장으로 잇는다. 끝맺는 문장부호는 언어마다 다르다(일본어·중국어 `。`).
void main() {
  test('제목이 이미 문장부호로 끝나면 더하지 않는다 — 전각 문장부호 포함', () {
    expect(failureSentence('다시 할까요?', '확인해주세요'), '다시 할까요?\n확인해주세요');
    expect(
      failureSentence('ログインできませんでした。', 'もう一度お試しください'),
      'ログインできませんでした。\nもう一度お試しください',
    );
    expect(failureSentence('できましたか！', 'どうぞ'), 'できましたか！\nどうぞ');
  });

}
