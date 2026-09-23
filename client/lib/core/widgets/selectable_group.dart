import 'package:flutter/material.dart';

import 'app_pressable.dart';

/// 선택 "상태"만 관리하는 위젯. 생김새는 전적으로 [itemBuilder]가 책임진다.
///
/// 목표 칩(다중선택, 세로 리스트)과 캐릭터 카드(단일선택, 가로 2열)가
/// 이 하나를 공유하되 서로 완전히 다르게 생길 수 있다.
///
/// 위젯을 통째로 공통화하면 두 화면의 요구가 갈릴 때마다 파라미터가 붙는다.
/// 같은 것(선택 로직)만 공통으로 두고 다른 것(표현)은 분리한다.
class SelectableGroup<T> extends StatelessWidget {
  const SelectableGroup({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    required this.itemBuilder,
    this.multiSelect = false,
    this.allowDeselect = true,
    this.gap = 0,
    this.semanticLabelOf,
  });

  final List<T> items;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  /// (context, item, isSelected) → 항목 위젯
  final Widget Function(BuildContext context, T item, bool isSelected) itemBuilder;

  /// true면 여러 개, false면 하나만 선택된다
  final bool multiSelect;

  /// 단일선택에서 이미 선택된 항목을 다시 눌러 해제할 수 있는지.
  /// 캐릭터처럼 "반드시 하나"인 경우 false로 둔다.
  final bool allowDeselect;

  /// 세로 리스트로 쓸 때 항목 사이 간격.
  /// 항목 위젯이 margin을 갖게 하면 마지막 항목에도 여백이 남는다.
  final double gap;

  /// 항목을 화면 낭독기가 읽는 이름 (#339). **그림뿐인 항목에만 준다.**
  ///
  /// 캐릭터 카드는 안에 그림뿐이고 이름(루루·포포)이 카드 밖에 있어, 누르는
  /// 카드 자체에는 이름이 없었다. 주면 고른 상태(selected)도 함께 알린다.
  /// 목표 칩처럼 안에 글자가 있으면 주지 않는다 — 그 글자가 이미 이름이다.
  final String Function(T item)? semanticLabelOf;

  void _toggle(T item) {
    final isSelected = selected.contains(item);

    if (multiSelect) {
      final next = Set<T>.from(selected);
      isSelected ? next.remove(item) : next.add(item);
      onChanged(next);
      return;
    }

    if (isSelected && !allowDeselect) return;
    onChanged(isSelected ? <T>{} : {item});
  }

  @override
  Widget build(BuildContext context) {
    // 레이아웃(세로 리스트/가로 그리드)은 부모가 정한다.
    // 여기서는 탭 처리만 입혀서 그대로 넘긴다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in items.indexed) ...[
          // 마지막 항목 뒤에는 간격을 두지 않는다
          if (index > 0) SizedBox(height: gap),
          _SelectableItem(
            onTap: () => _toggle(item),
            label: semanticLabelOf?.call(item),
            isSelected: selected.contains(item),
            child: itemBuilder(context, item, selected.contains(item)),
          ),
        ],
      ],
    );
  }

  /// 부모가 직접 레이아웃을 짤 때 쓰는 빌더.
  /// Row/GridView 등에 개별 항목을 배치해야 하는 경우 사용한다.
  Widget buildItem(BuildContext context, T item) {
    return _SelectableItem(
      onTap: () => _toggle(item),
      label: semanticLabelOf?.call(item),
      isSelected: selected.contains(item),
      child: itemBuilder(context, item, selected.contains(item)),
    );
  }
}

class _SelectableItem extends StatelessWidget {
  const _SelectableItem({
    required this.onTap,
    required this.child,
    required this.isSelected,
    this.label,
  });

  final VoidCallback onTap;
  final Widget child;
  final bool isSelected;

  /// null 이면 안의 글자가 그대로 이름이 된다 (지금까지와 같다).
  final String? label;

  @override
  Widget build(BuildContext context) {
    // 목표 칩·캐릭터 카드는 면적이 넓어 조금만 줄인다 (docs/motion.md)
    final pressable = AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: label == null ? child : ExcludeSemantics(child: child),
    );
    if (label == null) return pressable;

    // 고른 상태는 AppPressable 의 이름 자리로 담을 수 없어 여기서 감싼다.
    // 제스처 바깥에 두어야 이름과 누름 동작이 한 노드에 모인다.
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: label,
      child: pressable,
    );
  }
}
