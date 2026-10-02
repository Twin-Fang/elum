import 'package:elum/core/widgets/show_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// 제목과 할 일을 한 문장으로 잇는다. 끝맺는 문장부호는 언어마다 다르다(일본어·중국어 `。`).
void main() {
  test('기본은 마침표다 — 기존 한국어 문장 그대로', () {
    expect(
      failureSentence('로그인하지 못했어요', '잠시 후 다시 시도해주세요'),
      '로그인하지 못했어요.\n잠시 후 다시 시도해주세요',
    );
  });

  test('제목이 이미 문장부호로 끝나면 더하지 않는다 — 전각 문장부호 포함', () {
    expect(failureSentence('다시 할까요?', '확인해주세요'), '다시 할까요?\n확인해주세요');
    expect(
      failureSentence('ログインできませんでした。', 'もう一度お試しください'),
      'ログインできませんでした。\nもう一度お試しください',
    );
    expect(failureSentence('できましたか！', 'どうぞ'), 'できましたか！\nどうぞ');
  });

  test('문장부호가 없으면 stop 을 붙인다', () {
    expect(
      failureSentence('ログインできませんでした', 'もう一度お試しください', stop: '。'),
      'ログインできませんでした。\nもう一度お試しください',
    );
  });

  test('제목이 비면 할 일만 돌려준다', () {
    expect(failureSentence(null, '잠시 후 다시 해주세요'), '잠시 후 다시 해주세요');
    expect(failureSentence('', '잠시 후 다시 해주세요'), '잠시 후 다시 해주세요');
  });
}
