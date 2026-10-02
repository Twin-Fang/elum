import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/core/widgets/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

/// 번역이 길어도(스페인어) 고정 폭·고정 높이 위젯에서 넘치지 않는다 (Review Focus).
///
/// **파일럿이다.** 하네스(`pumpWithLocale` + 393×852 뷰포트 + 글자 상자 비교)가 동작함을 보이고
/// 가장 흔한 공용 위젯 셋을 본다. 전 화면 넘침 검사는 하위 계획 5 가 이 하네스로 한다.
/// RenderFlex 넘침은 `flutter_test_config.dart` 가 예외로 바꾸지만, 글자가 고정 높이 상자를
/// 삐져나가는 것은 예외가 아니라 **글자 상자 비교**로만 잡힌다.
/// 실패하는 위젯이 나오면 이 계획에서 고치지 않는다(ko 화면이 달라질 수 있다).
/// 그 테스트에 `skip: '계획 5 넘침 검사 대상 - <위젯>'` 을 달아 계획 5 로 넘긴다.
void main() {
  useFigmaViewport();

  const es = Locale('es');
  const longEs =
      'Todavía no has creado ninguna rutina para hoy, ¿quieres crear la primera ahora mismo?';

  /// 가장자리에 딱 맞는 것(66 높이 상자에 66 높이 글)도 들어온 것이다 - `Rect.contains` 는
  /// 오른쪽·아래 가장자리를 밖으로 보므로 쓰지 않는다.
  bool inside(Rect outer, Rect inner) =>
      inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;

  testWidgets('inside 판정 자체 검증 - 가장자리는 안, 삐져나가면 밖', (tester) async {
    const box = Rect.fromLTWH(0, 0, 100, 66);
    expect(inside(box, const Rect.fromLTWH(0, 0, 100, 66)), isTrue);
    expect(inside(box, const Rect.fromLTWH(0, 0, 100, 67)), isFalse);
    expect(inside(box, const Rect.fromLTWH(-1, 0, 100, 66)), isFalse);
  });

  testWidgets('음성 대조 - 좁은 폭에 긴 글을 넣으면 헬퍼가 넘침을 예외로 잡는다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(
        body: SizedBox(width: 60, child: Row(children: [Text(longEs)])),
      ),
      locale: es,
    );

    final error = tester.takeException();
    expect(error, isNotNull, reason: '넘치는 입력이 예외로 안 잡히면 파일럿은 공허하다');
    expect(error.toString(), contains('overflowed'));
  });

  testWidgets('음성 대조 - 글자 상자 비교는 고정 높이 상자를 삐져나간 글을 거른다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(
        body: SizedBox(
          key: ValueKey('box'),
          width: 120,
          height: 20,
          // OverflowBox 는 예외 없이 글만 상자 밖으로 내보낸다
          child: OverflowBox(
            maxHeight: double.infinity,
            alignment: Alignment.topLeft,
            child: Text(longEs),
          ),
        ),
      ),
      locale: es,
    );

    expect(tester.takeException(), isNull);
    final box = tester.getRect(find.byKey(const ValueKey('box')));
    final text = tester.getRect(find.text(longEs));
    expect(inside(box, text), isFalse, reason: '삐져나간 글을 inside 가 놓쳤다');
  });

  testWidgets('ElumButton - 긴 라벨이 버튼 상자 안에 있다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: ElumButton(label: longEs),
        ),
      ),
      locale: es,
      theme: AppTheme.lightFor(es),
    );

    final button = tester.getRect(find.byType(ElumButton));
    final text = tester.getRect(find.text(longEs));
    expect(inside(button, text), isTrue, reason: '버튼 $button 밖으로 글자 $text 가 나갔다');
  });

  testWidgets('SettingsTile - 긴 라벨이 줄 상자 안에 있다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(body: SettingsTile(label: longEs, onTap: null)),
      locale: es,
      theme: AppTheme.lightFor(es),
    );

    final tile = tester.getRect(find.byType(SettingsTile));
    final text = tester.getRect(find.text(longEs));
    expect(inside(tile, text), isTrue, reason: '줄 $tile 밖으로 글자 $text 가 나갔다');
  });

  testWidgets('ElumDialogCard - 긴 제목이 화면 폭 안에 있다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(
        body: Center(
          child: ElumDialogCard<void>(
            title: longEs,
            actions: [ElumDialogAction(label: 'Aceptar')],
          ),
        ),
      ),
      locale: es,
      theme: AppTheme.lightFor(es),
    );

    final text = tester.getRect(find.text(longEs));
    expect(text.left, greaterThanOrEqualTo(0));
    expect(text.right, lessThanOrEqualTo(393));
    expect(tester.takeException(), isNull);
  });
}
