import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 누를 수 있는데 **읽을 이름이 없는** 시맨틱 노드를 모은다 (#339).
///
/// 실기기 판정(`uiautomator dump` 에서 `clickable="true"` 인데 `text` 도
/// `content-desc` 도 빈 노드)을 위젯 테스트에서 같은 기준으로 잰다.
/// 화면 낭독기는 이런 자리에서 "버튼" 말고는 아무것도 읽지 못한다.
///
/// 부모에 합쳐진 노드는 따로 드러나지 않으므로(안드로이드도 부모 하나로 본다)
/// 건너뛴다. 결과는 실패 메시지에서 자리를 찾을 수 있게 좌표를 담는다.
List<String> unnamedTapTargets(WidgetTester tester) {
  final found = <String>[];

  void visit(SemanticsNode node) {
    if (!node.isMergedIntoParent && !node.isInvisible) {
      final data = node.getSemanticsData();
      final tappable =
          data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress);
      final named = [
        data.label,
        data.value,
        data.tooltip,
      ].any((s) => s.trim().isNotEmpty);
      if (tappable && !named) {
        // 좌표만으로는 어느 위젯인지 찾기 어려워 동작·플래그까지 담는다
        found.add('노드 #${node.id} $data');
      }
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return found;
}

/// [label] 이 **누를 수 있는 버튼 노드 자체**에 붙어 있는지 본다.
///
/// 이름과 누름 동작이 다른 노드로 갈라지면 `find.bySemanticsLabel` 은 찾아도
/// 실기기에서는 이름 없는 버튼과 누를 수 없는 그림이 따로 읽힌다. 그래서
/// 이름만이 아니라 같은 노드에 탭 동작이 있는지까지 함께 본다.
void expectLabeledButton(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(label);
  expect(finder, findsOneWidget, reason: '"$label" 이름이 한 곳에만 있어야 한다');
  expect(
    tester.getSemantics(finder),
    containsSemantics(label: label, isButton: true, hasTapAction: true),
    reason: '"$label" 이 누르는 노드에 붙어 있어야 한다',
  );
}
