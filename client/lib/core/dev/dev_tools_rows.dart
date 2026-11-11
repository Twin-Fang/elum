part of 'dev_tools_overlay.dart';

/// 메뉴 한 줄: 아이콘 + 이름 + 설명 (+ 오른쪽 지금 값)
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.currentValueLabel,
    this.isValueChanged = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  /// 되돌릴 수 없는 동작 (빨간 글자)
  final bool isDestructive;

  /// 오른쪽 칩에 보일 지금 값. null 이면 칩 없음
  final String? currentValueLabel;

  /// 지금 값이 기본값과 다름 (주황 칩)
  final bool isValueChanged;

  @override
  Widget build(BuildContext context) {
    final valueText = currentValueLabel;
    return _RowFrame(
      icon: icon,
      label: label,
      subtitle: subtitle,
      isDestructive: isDestructive,
      isEnabled: onTap != null,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (valueText != null) _ValueChip(valueText, isChanged: isValueChanged),
          if (onTap != null) const Icon(Icons.chevron_right, size: 20, color: _DevPalette.caption),
        ],
      ),
    );
  }
}

/// 켜고 끄는 줄 (스위치와 이름을 한 접근성 노드로 묶음)
class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isOn,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isOn;

  /// null 이면 잠김 (반영 중 등)
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChangedCallback = onChanged;
    return MergeSemantics(
      child: _RowFrame(
        icon: icon,
        label: label,
        subtitle: subtitle,
        isEnabled: true,
        onTap: onChangedCallback == null ? null : () => onChangedCallback(!isOn),
        trailing: Switch(value: isOn, activeTrackColor: _DevPalette.success, onChanged: onChangedCallback),
      ),
    );
  }
}

/// 줄 공통 틀: 색 네모 아이콘 · 이름(15) · 설명(12, 최대 2줄) · 오른쪽
class _RowFrame extends StatelessWidget {
  const _RowFrame({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isEnabled,
    required this.onTap,
    required this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isEnabled;
  final bool isDestructive;
  final VoidCallback? onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final accent = isDestructive ? _DevPalette.destructive : const Color(0xFF3A3A3C);
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? _DevPalette.destructive : _DevPalette.title,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.3, color: _DevPalette.caption),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// 지금 값 칩 (기본값 회색, 바뀐 값 주황)
class _ValueChip extends StatelessWidget {
  const _ValueChip(this.text, {this.isChanged = false});

  final String text;
  final bool isChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isChanged ? _DevPalette.changedBackground : _DevPalette.neutralChipBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isChanged ? _DevPalette.changed : _DevPalette.caption,
        ),
      ),
    );
  }
}

/// 카드 버튼 (주 = 흰 바탕, 보조 = 흰 테두리)
class _OverviewActionButton extends StatelessWidget {
  const _OverviewActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
    return SizedBox(
      height: 48,
      child: isPrimary
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _DevPalette.title,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: shape,
              ),
              onPressed: onPressed,
              child: content,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: shape,
              ),
              onPressed: onPressed,
              child: content,
            ),
    );
  }
}
