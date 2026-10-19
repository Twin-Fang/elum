import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 태블릿 레이아웃의 공통 지점 우회 금지 (`lib/core/layout/` 밖의 `lib/core`·`lib/features`)
///
/// 남은 위반은 동결 목록: 새로 늘면 실패, 고쳐졌는데 목록에 남아도 실패 (feature_raw_widget_rule_test 방식)
void main() {
  /// 화면 크기 직접 읽기: ScreenUtil 싱글턴·`1.sw`/`1.sh` 는 창이 아니라 폰 열 기준이 필요한 곳에서 틀린다
  final rawScreenUtilSize = RegExp(r'\.(sw|sh)\b|\bScreenUtil\(\)');

  /// 숫자 breakpoint·기기 종류 흉내: 등급은 `context.sizeClass` 만 쓴다
  final rawBreakpoint = RegExp(r'\.width\s*[<>]=?\s*(600|840)\b|\bisTablet\b');

  /// 시트·팝업을 공통 헬퍼(showElumSheet·showElumDialog) 밖에서 직접 띄우기
  final rawOverlay = RegExp(
    r'\b(showModalBottomSheet|showDialog|showGeneralDialog|showCupertinoDialog|showBottomSheet)\s*[<(]',
  );

  /// 공통 헬퍼 본체는 직접 호출이 정상
  const overlayHelperFiles = {
    'core/widgets/elum_bottom_sheet.dart',
    'core/widgets/elum_dialog.dart',
  };

  /// 동결 목록 키: `lib 기준 경로 | 줄 내용(trim)` > 이유
  const frozenRawScreenUtilSize = <String, String>{};
  const frozenRawBreakpoint = <String, String>{};
  const frozenRawOverlay = <String, String>{
    'features/credit/presentation/credit_blocked_dialog.dart | showDialog<void>(':
        '닫을 수 없는 대기 팝업. 카드 폭이 322 x 배율로 이미 고정이라 늘어나지 않음',
    'features/guardian/presentation/widgets/step_card_viewer.dart | return showGeneralDialog<void>(':
        '전체 화면 카드 뷰어. 태블릿 구성은 보호자 적응형 단계(P3)에서 다룬다',
  };

  /// `lib/core`(layout 제외)·`lib/features` 에서 패턴이 든 줄 (주석 줄 제외) > `경로 | 줄 내용`
  Set<String> scanLib(RegExp pattern, {Set<String> skipFiles = const {}}) {
    final hits = <String>{};
    for (final root in const ['lib/core', 'lib/features']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/').replaceFirst('lib/', '');
        if (path.startsWith('core/layout/') || skipFiles.contains(path)) continue;
        for (final line in entity.readAsLinesSync()) {
          final code = line.trim();
          if (code.startsWith('//')) continue;
          if (pattern.hasMatch(code)) hits.add('$path | $code');
        }
      }
    }
    return hits;
  }

  void expectFrozen(
    RegExp pattern,
    Map<String, String> frozen,
    String guide, {
    Set<String> skipFiles = const {},
  }) {
    final hits = scanLib(pattern, skipFiles: skipFiles);
    final added = hits.difference(frozen.keys.toSet()).toList()..sort();
    final stale = frozen.keys.toSet().difference(hits).toList()..sort();
    expect(added, isEmpty, reason: '$guide\n${added.join('\n')}');
    expect(stale, isEmpty, reason: '고쳐진 줄이다. 동결 목록에서 지운다:\n${stale.join('\n')}');
  }

  // 깨지면: 태블릿 폰 비율 열 안에서 창 크기로 계산한 폭이 열을 넘는다
  test('화면 크기는 1.sw·1.sh·ScreenUtil() 대신 MediaQuery 나 context.layoutMetrics 로 읽는다', () {
    expectFrozen(
      rawScreenUtilSize,
      frozenRawScreenUtilSize,
      '창이 아니라 이 화면의 폭이 필요하면 MediaQuery.sizeOf(context) 를 쓴다',
    );
  });

  // 깨지면: 화면마다 다른 breakpoint 가 생겨 통일감이 깨진다
  test('창 등급은 숫자 비교 대신 context.sizeClass 로 가른다', () {
    expectFrozen(
      rawBreakpoint,
      frozenRawBreakpoint,
      '등급 경계는 AppLayout 토큰이 가진다. context.sizeClass / context.layoutMetrics 를 쓴다',
    );
  });

  // 깨지면: 시트·팝업이 태블릿에서 전폭으로 늘어난다
  test('시트·팝업은 showElumSheet·showElumDialog 로만 띄운다', () {
    expectFrozen(
      rawOverlay,
      frozenRawOverlay,
      'core/widgets 의 showElumSheet / showElumDialog 를 쓴다',
      skipFiles: overlayHelperFiles,
    );
  });

  // 깨지면: 새 라우트가 태블릿 프레임을 거치지 않아 전폭으로 늘어난다
  test('모든 GoRoute 는 slidePage·fadePage·flowPage·AdaptivePageFrame 중 하나를 거친다', () {
    final frameTokens = RegExp(r'slidePage\(|fadePage\(|flowPage\(|AdaptivePageFrame\(');
    final unframed = <String>[];
    for (final entity in Directory('lib/core/router').listSync()) {
      if (entity is! File || !entity.path.contains('routes_')) continue;
      final chunks = entity.readAsStringSync().split('GoRoute(').skip(1);
      var index = 0;
      for (final chunk in chunks) {
        index++;
        if (!frameTokens.hasMatch(chunk.split('GoRoute(').first)) {
          unframed.add('${entity.path} #$index');
        }
      }
    }
    expect(unframed, isEmpty, reason: '프레임을 거치지 않는 라우트:\n${unframed.join('\n')}');
  });

  test('검사식: 직접 호출은 잡고 헬퍼 호출은 통과', () {
    expect(rawScreenUtilSize.hasMatch('final w = 1.sw - 32.w;'), isTrue);
    expect(rawScreenUtilSize.hasMatch('width: 100.w,'), isFalse);
    expect(rawBreakpoint.hasMatch('if (size.width >= 600) {'), isTrue);
    expect(rawBreakpoint.hasMatch('final isWide = context.sizeClass.index > 0;'), isFalse);
    expect(rawOverlay.hasMatch('await showDialog<void>('), isTrue);
    expect(rawOverlay.hasMatch('await showElumDialog<void>('), isFalse);
  });
}
