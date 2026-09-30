import 'dart:io';
import 'package:flutter/services.dart' show ByteData;
import 'dart:ui' as ui;

import 'package:elum/features/guardian/presentation/widgets/pictogram_art.dart';
import 'package:elum/shared/pictogram/svg_style_inliner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

  test('쉼표로 묶은 선택자와 뒤에 오는 같은 속성 규칙(덮어쓰기)을 CSS 처럼 처리한다', () {
    final out = inlineSvgClassStyles(
      '$wrap<style>.st1,.st2{fill:none;stroke-width:21}.st2{stroke-width:14}</style>'
      '<path class="st1"/><path class="st2"/></svg>',
    );
    final tags = RegExp(r'<path[^>]*/>').allMatches(out).map((m) => m.group(0)!).toList();
    expect(tags[0], contains('stroke-width="21"'));
    expect(tags[1], contains('stroke-width="14"'));
    expect(tags[1], isNot(contains('stroke-width="21"')), reason: '같은 속성이 두 번 붙으면 SVG 가 깨진다');
  });

  test('이미 같은 속성이 있으면 CSS 가 이긴다 (브라우저와 같게) — 속성이 중복되지 않는다', () {
    final out = inlineSvgClassStyles(
      '$wrap<style>.a{fill:#ff0000}</style><path class="a" fill="#000000"/></svg>',
    );
    expect(RegExp('fill=').allMatches(out).length, 1);
    expect(out, contains('fill="#ff0000"'));
  });

  test('<style> 이 없으면 그대로 돌려준다 (나머지 549개)', () {
    const svg = '<svg><path class="aac-skin-fill" fill="#9e5c26"/></svg>';
    expect(inlineSvgClassStyles(svg), svg);
  });

  test('모르는 클래스는 무시하고 죽지 않는다', () {
    final out = inlineSvgClassStyles('$wrap<style>.a{fill:red}</style><path class="zzz"/></svg>');
    expect(out, contains('<path'));
    expect(tester0(out), isTrue);
  });

  test('<style> 을 쓰는 실제 SVG 262개 전부에서 style·클래스 참조가 남지 않는다', () {
    var styled = 0;
    for (final f in Directory('assets/pictograms').listSync().whereType<File>()) {
      if (!f.path.endsWith('.svg')) continue;
      final raw = f.readAsStringSync();
      if (!raw.contains('<style')) continue;
      styled++;
      final out = inlineSvgClassStyles(raw);
      expect(out, isNot(contains('<style')), reason: f.path);
      expect(out, isNot(contains('class="st')), reason: f.path);
      // 중복 속성이 없다 — 한 태그 안에서 fill 이 두 번 나오면 XML 이 깨진다
      for (final tag in RegExp(r'<path[^>]*>').allMatches(out)) {
        expect(RegExp(r'\sfill=').allMatches(tag.group(0)!).length, lessThanOrEqualTo(1), reason: f.path);
        expect(RegExp(r'\sstroke-width=').allMatches(tag.group(0)!).length, lessThanOrEqualTo(1), reason: f.path);
      }
    }
    expect(styled, 262);
  });

  testWidgets('<style> 을 쓰는 ask_,_to 의 빨간 입술이 검게 뭉개지지 않고 색으로 그려진다', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: const SizedBox(
                width: 300,
                height: 300,
                child: PictogramArt(id: 'ask_,_to', label: '묻기', fallbackBuilder: _blank),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    final image = await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return boundary.toImage();
    });
    final data = (await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final reddish = _count(data, (r, g, b) => r > 200 && g < 90 && b < 90);
    expect(reddish, greaterThan(200), reason: '빨간 입술(#ed1e29)이 있어야 한다 — 검은 실루엣이면 0');
  });
}

bool tester0(String svg) => svg.contains('<svg') && svg.contains('</svg>');

Widget _blank(BuildContext _) => const SizedBox.shrink();

int _count(ByteData d, bool Function(int r, int g, int b) test) {
  var n = 0;
  for (var i = 0; i + 3 < d.lengthInBytes; i += 4) {
    if (test(d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2))) n++;
  }
  return n;
}
