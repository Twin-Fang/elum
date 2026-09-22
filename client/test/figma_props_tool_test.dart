@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 시안 속성 대조 도구가 **여전히 결함을 잡는지** 확인한다 (이슈 #344).
///
/// **왜 Dart 테스트로 묶나.** 도구는 파이썬인데, 파이썬만 따로 돌리는 사람은 없다.
/// `flutter test` 안에 넣어야 실제로 돌아간다.
///
/// 검사 도구가 조용히 망가지면 **"이상 없음"만 찍어 댄다.** 그건 검사가 없는 것보다
/// 나쁘다 — 믿고 안 보게 되기 때문이다. 실제로 탐침 자리를 `r × 0.3` 으로 잡았다가
/// (곡선 바깥 조건은 `r × 0.293`) 둥근 모서리를 각졌다고 보고하는 상태였다.
///
/// 도구의 `--self-test` 가 네 가지를 본다 — 합성 도형 둘(둥근/각진)과
/// **실물 회귀 샘플 둘**(#345 가 났을 때의 일과 시트, 그리고 고친 시트).
void main() {
  test('시안 속성 대조 도구 자가검사', () async {
    final python = await _findPython();
    if (python == null) {
      markTestSkipped('python3 이 없다');
      return;
    }
    if (!await _hasDeps(python)) {
      markTestSkipped('pillow/numpy 가 없다 — python3 -m pip install pillow numpy');
      return;
    }

    final result = await Process.run(
      python,
      ['tool/figma_props.py', '--self-test'],
      workingDirectory: Directory.current.path,
    );

    // 출력째로 보여 준다 — 어느 항목이 깨졌는지 여기서 바로 읽혀야 한다.
    expect(
      result.exitCode,
      0,
      reason: '도구 자가검사 실패\n${result.stdout}${result.stderr}',
    );
    expect(result.stdout.toString(), contains('각진 시트'));
  });
}

Future<String?> _findPython() async {
  for (final name in ['python3', 'python']) {
    try {
      final r = await Process.run(name, ['--version']);
      if (r.exitCode == 0) return name;
    } on ProcessException {
      continue;
    }
  }
  return null;
}

Future<bool> _hasDeps(String python) async {
  final r = await Process.run(python, ['-c', 'import numpy, PIL']);
  return r.exitCode == 0;
}
