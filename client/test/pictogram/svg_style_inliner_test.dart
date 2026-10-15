
import 'package:elum/shared/pictogram/svg_style_inliner.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_svg 는 `<style>` 의 클래스 색을 못 읽어 262개 심볼이 검은 실루엣으로 그려진다 (#469).
/// 원본 파일은 고치지 않고(CC BY-SA), 읽을 때 메모리에서만 속성으로 풀어 준다.
void main() {
  const wrap = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">';

  test('클래스 규칙을 그 클래스를 쓴 요소의 속성으로 풀고 style·class 를 없앤다', () {
    final out = inlineSvgClassStyles(
      '$wrap<style>.st0{fill:#ed1e29}.st1{fill:none;stroke:#231f20;stroke-width:21}</style>'
      '<path class="st0" d="M0 0"/><path class="st1" d="M1 1"/></svg>',
    );
    expect(out, isNot(contains('<style')));
    expect(out, isNot(contains('class=')));
    expect(out, contains('fill="#ed1e29"'));
    expect(out, contains('fill="none"'));
    expect(out, contains('stroke="#231f20"'));
    expect(out, contains('stroke-width="21"'));
    expect(out, contains('d="M0 0"'));
  });

  test('이미 같은 속성이 있으면 CSS 가 이긴다 (브라우저와 같게) — 속성이 중복되지 않는다', () {
    final out = inlineSvgClassStyles(
      '$wrap<style>.a{fill:#ff0000}</style><path class="a" fill="#000000"/></svg>',
    );
    expect(RegExp('fill=').allMatches(out).length, 1);
    expect(out, contains('fill="#ff0000"'));
  });

  test('모르는 클래스는 무시하고 죽지 않는다', () {
    final out = inlineSvgClassStyles('$wrap<style>.a{fill:red}</style><path class="zzz"/></svg>');
    expect(out, contains('<path'));
    expect(tester0(out), isTrue);
  });

}

bool tester0(String svg) => svg.contains('<svg') && svg.contains('</svg>');
