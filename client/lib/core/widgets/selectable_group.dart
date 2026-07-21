import 'package:flutter/material.dart';

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
        for (final item in items)
          _SelectableItem(
            onTap: () => _toggle(item),
            child: itemBuilder(context, item, selected.contains(item)),
          ),
      ],
    );
  }

  /// 부모가 직접 레이아웃을 짤 때 쓰는 빌더.
  /// Row/GridView 등에 개별 항목을 배치해야 하는 경우 사용한다.
  Widget buildItem(BuildContext context, T item) {
    return _SelectableItem(
      onTap: () => _toggle(item),
      child: itemBuilder(context, item, selected.contains(item)),
    );
  }
}

class _SelectableItem extends StatelessWidget {
  const _SelectableItem({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
