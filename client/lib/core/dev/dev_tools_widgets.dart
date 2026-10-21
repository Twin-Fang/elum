part of 'dev_tools_overlay.dart';

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  /// 되돌릴 수 없는 동작 (빨간 글자)
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade700 : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}

/// 메뉴 묶음 제목
class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
      ),
    );
  }
}

/// 여럿 중 하나 고르기 행 (고른 것에 체크)
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return ListTile(
      title: Text(label),
      subtitle: subtitleText == null ? null : Text(subtitleText, style: const TextStyle(fontSize: 12)),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
      selected: isSelected,
      onTap: onTap,
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
        style: TextStyle(fontSize: 12, color: isError ? Colors.red.shade700 : Colors.grey.shade700),
      ),
    );
  }
}

/// 실패 > 한 줄 (종류 · 서버 코드 · 서버 문구)
String _describeFailure(AppFailure failure) => [
  failure.fault.name,
  ?failure.server?.badge,
  ?failure.serverMessage,
].join(' · ');

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
