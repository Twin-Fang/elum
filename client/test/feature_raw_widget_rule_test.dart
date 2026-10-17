import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 기능 코드(`lib/features/`)의 공통 지점 우회 금지 3개: debugPrint, 스피너 직접 사용, Colors 직접 사용
/// 남은 위반은 동결 목록 — 새로 늘면 실패, 고쳐졌는데 목록에 남아도 실패 (check_layer_imports_test 방식)
void main() {
  /// 동결 목록 키: `lib 기준 경로 | 줄 내용(trim)` > 이유. 줄 번호는 쓰지 않음 (위아래 수정에 안 흔들리게)
  const frozenDebugPrints = <String, String>{};

  const frozenSpinners = <String, String>{
    'features/guardian/presentation/routine_loading_screen.dart | child: CircularProgressIndicator(':
        'ElumSpinner 에 backgroundColor 없음 (투명 트랙 지정이 기본값과 같은지 미확인)',
  };

  const frozenColors = <String, String>{
    'features/guardian/presentation/widgets/pictogram_art.dart | color: Colors.white,':
        '시안 그림칸 흰 배경, 토큰 미정',
    'features/guardian/presentation/widgets/card_review_reorder_list.dart | color: Colors.black.withValues(alpha: 0.24 * strength),':
        '끌기 정도(strength)에 따라 알파가 변하는 그림자',
    'features/guardian/presentation/widgets/step_card_viewer.dart | barrierColor: Colors.black.withValues(alpha: 0.7),':
        '시안 Scrim 검정 70% (dialogScrim 50% 와 다른 값), 토큰 미정',
    'features/guardian/presentation/widgets/step_card_viewer.dart | Colors.white,':
        '어두운 막 위 닫기 아이콘 흰색, 토큰 미정',
    'features/child/presentation/child_home_screen.dart | color: Colors.black.withValues(alpha: 0.7),':
        '보상 글 검정 70%, 토큰 미정',
    'features/guardian/presentation/widgets/routine_detail_sheet.dart | color: Colors.black.withValues(alpha: 0.26 * t),':
        '시트 펼침 정도(t)에 따라 알파가 변하는 그림자',
  };

  final debugPrintCall = RegExp(r'\bdebugPrint\(');
  final rawSpinner = RegExp(r'\b(CircularProgressIndicator|CupertinoActivityIndicator)(?:\.\w+)?\(');
  // AppColors·context.colors 는 단어 경계로 걸러짐, transparent 는 토큰 대상 아님
  final rawColors = RegExp(r'\bColors\.(?!transparent\b)[a-zA-Z]');

  /// 기능 코드에서 패턴이 든 줄 (주석 줄 제외) > `경로 | 줄 내용`
  Set<String> scanFeatures(RegExp pattern) {
    final hits = <String>{};
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/').replaceFirst('lib/', '');
      for (final line in entity.readAsLinesSync()) {
        final code = line.trim();
        if (code.startsWith('//')) continue;
        if (pattern.hasMatch(code)) hits.add('$path | $code');
      }
    }
    return hits;
  }

  /// 늘어난 위반·고쳐진 동결 줄 검사
  void expectFrozen(RegExp pattern, Map<String, String> frozen, String guide) {
    final hits = scanFeatures(pattern);
    final added = hits.difference(frozen.keys.toSet()).toList()..sort();
    final stale = frozen.keys.toSet().difference(hits).toList()..sort();
    expect(added, isEmpty, reason: '$guide\n${added.join('\n')}');
    expect(stale, isEmpty, reason: '고쳐진 줄이다. 동결 목록에서 지운다:\n${stale.join('\n')}');
  }

  // 깨지면: 실패 기록이 의견 첨부 기록(AppLogBuffer)에 안 남아 제보로 추적 불가
  test('기능 코드는 debugPrint 대신 AppLogger 를 쓴다', () {
    expectFrozen(debugPrintCall, frozenDebugPrints, 'AppLogger.error / AppLogger.info 를 쓴다');
  });

  // 깨지면: 화면마다 스피너 굵기·크기가 제각각
  test('기능 코드는 스피너를 직접 만들지 않고 ElumSpinner 를 쓴다', () {
    expectFrozen(rawSpinner, frozenSpinners, 'core/widgets/elum_spinner.dart 의 ElumSpinner 를 쓴다');
  });

  // 깨지면: 색이 토큰 밖에 흩어져 한 곳 수정으로 바뀌지 않음
  test('기능 코드는 Colors.<이름> 대신 AppColors 토큰을 쓴다', () {
    expectFrozen(rawColors, frozenColors, '색은 context.colors 토큰을 쓴다. 없으면 AppColors 에 먼저 더한다');
  });

  test('검사식: AppColors·transparent 는 통과, Colors.white 는 잡음', () {
    expect(rawColors.hasMatch('color: context.colors.surface,'), isFalse);
    expect(rawColors.hasMatch('AppColors.light'), isFalse);
    expect(rawColors.hasMatch('color: Colors.transparent,'), isFalse);
    expect(rawColors.hasMatch('color: Colors.white,'), isTrue);
    expect(rawSpinner.hasMatch('const ElumSpinner(size: 24)'), isFalse);
    expect(rawSpinner.hasMatch('CircularProgressIndicator.adaptive()'), isTrue);
  });
}
