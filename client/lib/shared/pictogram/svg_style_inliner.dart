/// SVG 의 `<style>` 클래스 규칙을 각 요소의 속성으로 풀어 준다.
///
/// flutter_svg 는 `<style>` 을 읽지 못해 버리므로, `<style>.st0{fill:#ed1e29}</style>` 처럼
/// 클래스로 색을 적은 심볼(Mulberry Symbols 의 약 32%)은 **색이 사라지고 검은 실루엣**이 된다.
///
/// **원본은 고치지 않는다.** 읽어 온 문자열만 메모리에서 바꿔 렌더러에 넘기고 번들 SVG 는
/// 그대로 둔다(CC BY-SA 4.0 — 변형하지 않는다).
///
/// 지원 범위: `.클래스` 선택자(쉼표 목록 포함)와 `속성:값;` 선언. 뒤 규칙이 앞 규칙을 덮어쓴다.
/// 그 밖의 선택자는 무시한다.
String inlineSvgClassStyles(String svg) {
  if (!svg.contains('<style')) return svg;

  // 1) 규칙 수집: 클래스 이름 → (속성 → 값), 정의된 순서대로 덮어쓴다
  final rules = <String, Map<String, String>>{};
  final styleBlock = RegExp(r'<style[^>]*>(.*?)</style>', dotAll: true);
  for (final block in styleBlock.allMatches(svg)) {
    final css = block.group(1) ?? '';
    for (final rule in RegExp(r'([^{}]+)\{([^}]*)\}').allMatches(css)) {
      final declarations = <String, String>{};
      for (final part in (rule.group(2) ?? '').split(';')) {
        final i = part.indexOf(':');
        if (i <= 0) continue;
        final name = part.substring(0, i).trim();
        final value = part.substring(i + 1).trim();
        if (name.isNotEmpty && value.isNotEmpty) declarations[name] = value;
      }
      for (final selector in (rule.group(1) ?? '').split(',')) {
        final s = selector.trim();
        if (!RegExp(r'^\.[A-Za-z0-9_-]+$').hasMatch(s)) continue;
        rules.putIfAbsent(s.substring(1), () => {}).addAll(declarations);
      }
    }
  }

  // 2) <style> 를 걷어 낸다 — 남기면 렌더러가 경고를 낸다
  var out = svg.replaceAll(styleBlock, '');

  // 3) class 를 가진 여는 태그마다 규칙을 속성으로 붙이고 class 를 지운다
  final tag = RegExp(r'<([A-Za-z][\w:-]*)((?:\s[^<>]*?)?)(/?)>');
  out = out.replaceAllMapped(tag, (m) {
    final attrs = m.group(2) ?? '';
    final cls = RegExp(r'\sclass="([^"]*)"').firstMatch(attrs);
    if (cls == null) return m.group(0)!;

    final merged = <String, String>{};
    for (final name in (cls.group(1) ?? '').split(RegExp(r'\s+'))) {
      final r = rules[name];
      if (r != null) merged.addAll(r);
    }

    var rest = attrs.replaceFirst(cls.group(0)!, '');
    for (final entry in merged.entries) {
      // CSS 가 속성을 이긴다 — 같은 속성이 이미 있으면 지우고 다시 붙인다(중복 속성은 XML 오류)
      rest = rest.replaceAll(RegExp('\\s${RegExp.escape(entry.key)}="[^"]*"'), '');
    }
    final added = merged.entries.map((e) => ' ${e.key}="${e.value}"').join();
    return '<${m.group(1)}$rest$added${m.group(3)}>';
  });
  return out;
}
