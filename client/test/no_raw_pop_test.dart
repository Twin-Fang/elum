import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// go_router 의 인자 없는 pop 을 막는다. 돌아갈 화면이 없으면 예외를 던져 버튼이 먹통이 된다.
/// 뒤로가기·돌아가기는 `context.popOrHome()` 을 쓴다.
///
/// 대상 아님: 결과를 돌려주는 `context.pop(값)`, 시트·다이얼로그의 `Navigator.of(context).pop()`.
void main() {
  /// 정말 써야 하는 곳. 경로 → 사유.
  const allowed = <String, String>{};

  // context.pop() · context.pop<T>() · tear-off context.pop · GoRouter.of(context).pop()
  final rawPop = RegExp(
    r'(\bcontext|GoRouter\.of\(\s*context\s*\))\s*\.\s*pop\b(?!OrHome)(\s*<[^>]*>)?\s*(\(\s*\)|(?!\())',
  );

  group('검사식', () {
    for (final bad in [
      'onBack: () => context.pop(),',
      'onBack: context.pop,',
      'context.pop<void>();',
      'GoRouter.of(context).pop();',
      'context\n  .pop();',
    ]) {
      test('잡는다: ${bad.replaceAll('\n', '⏎')}', () {
        expect(rawPop.hasMatch(bad), isTrue);
      });
    }
    for (final ok in [
      'onBack: context.popOrHome,',
      'context.popOrHome();',
      'context.pop(result);',
      'Navigator.of(context).pop();',
    ]) {
      test('통과: $ok', () => expect(rawPop.hasMatch(ok), isFalse));
    }
  });

  test('lib 에 인자 없는 go_router pop 이 없다', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (allowed.containsKey(path)) continue;
      // 줄바꿈된 호출도 잡으려고 파일 전체에서 찾되, 주석 줄은 지운다
      final code = f
          .readAsLinesSync()
          .map((l) => l.trimLeft().startsWith('//') ? '' : l)
          .join('\n');
      for (final m in rawPop.allMatches(code)) {
        final line = '\n'.allMatches(code.substring(0, m.start)).length + 1;
        hits.add('$path:$line: ${m.group(0)!.replaceAll('\n', ' ')}');
      }
    }
    expect(
      hits,
      isEmpty,
      reason:
          'context.popOrHome() 을 쓰거나, 정말 필요하면 allowed 에 사유와 함께 올린다.\n${hits.join('\n')}',
    );
  });
}
