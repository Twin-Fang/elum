part of 'dev_tools_overlay.dart';

/// 개발자 도구 전용 색 (출시 화면이 아니라 디자인 토큰 규칙 밖, check_design_rules 예외)
abstract final class _DevPalette {
  static const sheetBackground = Color(0xFFF2F2F7);
  static const groupBackground = Colors.white;
  static const title = Color(0xFF1C1C1E);
  static const caption = Color(0xFF6E6E73);
  static const divider = Color(0xFFE5E5EA);
  static const destructive = Color(0xFFD70015);
  // 기본값과 다른 값 (흉내 켜짐, 운영 아닌 서버)
  static const changed = Color(0xFFE8590C);
  static const changedBackground = Color(0xFFFFF0E6);
  static const neutralChipBackground = Color(0xFFEDEDF0);
  static const overviewBackground = Color(0xFF1C1C1E);
  static const overviewCaption = Color(0xFFAEAEB2);
  static const success = Color(0xFF34C759);
}

/// 메뉴 묶음: 제목 + 흰 둥근 카드(줄 사이 구분선) + 아래 설명
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final footerText = footer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DevPalette.caption),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: _DevPalette.groupBackground,
              child: Column(
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0) const Divider(height: 1, thickness: 1, indent: 56, color: _DevPalette.divider),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
          if (footerText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(footerText, style: const TextStyle(fontSize: 12, color: _DevPalette.caption)),
            ),
        ],
      ),
    );
  }
}

/// 하위 화면 안 묶음 제목
class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DevPalette.caption),
      ),
    );
  }
}

/// 여럿 중 하나 고르기 행 (고른 것에 체크)
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.label, required this.isSelected, required this.onTap, this.subtitle});

  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 15, color: _DevPalette.title)),
      subtitle: subtitleText == null
          ? null
          : Text(subtitleText, style: const TextStyle(fontSize: 12, color: _DevPalette.caption)),
      trailing: isSelected ? const Icon(Icons.check, color: _DevPalette.success) : null,
      selected: isSelected,
      onTap: onTap,
    );
  }
}

/// 여럿 중 하나를 한 줄에서 바로 고르기 (요금제 흉내: 서버 값 · Free · Pro)
class _SegmentedPicker<T> extends StatelessWidget {
  const _SegmentedPicker({required this.options, required this.selected, required this.onSelected});

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: _DevPalette.neutralChipBackground, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (final (option, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: option == selected,
                child: GestureDetector(
                  onTap: () => onSelected(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: option == selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: option == selected ? FontWeight.w700 : FontWeight.w500,
                        color: _DevPalette.title,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 화면 안내·결과 문구 한 덩어리 ([isError] 면 빨간 글자)
class _Message extends StatelessWidget {
  const _Message(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SelectableText(
        text,
        style: TextStyle(fontSize: 12, color: isError ? _DevPalette.destructive : _DevPalette.caption),
      ),
    );
  }
}

/// 실패 > 한 줄 (종류 · 서버 코드 · 서버 문구)
String _describeFailure(AppFailure failure) =>
    [failure.fault.name, ?failure.server?.badge, ?failure.serverMessage].join(' · ');

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: const Color(0xFFC7C7CC), borderRadius: BorderRadius.circular(3)),
    );
  }
}
