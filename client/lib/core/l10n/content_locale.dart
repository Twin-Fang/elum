import 'package:flutter/widgets.dart';

/// 일과 언어로 인정하는 코드 다섯.
const _contentLanguages = {'ko', 'en', 'ja', 'zh', 'es'};

/// 서버가 준 일과 언어 값을 정리한다. **다섯 코드 밖이거나 깨진 값은 `ko`** 다 — 구버전 일과·서버 응답이
/// 전부 한국어 일과였고, 모르는 값 하나로 카드가 안 그려지면 안 된다.
String normalizeContentLanguage(Object? value) =>
    value is String && _contentLanguages.contains(value) ? value : 'ko';

/// 일과 언어 코드 → [Locale]. 모르는 값은 `ko`다.
Locale contentLocaleOf(String? language) => switch (language) {
  'en' => const Locale('en'),
  'ja' => const Locale('ja'),
  'zh' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  'es' => const Locale('es'),
  _ => const Locale('ko'),
};

/// 아래 글자를 일과 언어로 그린다.
///
/// 이룸이 휴대폰은 화면 문구를 **자기 OS 언어**로, 카드 글을 **일과 언어**로 보여준다.
/// 두 언어가 다를 때 한자(일본어/중국어)의 글리프와 줄바꿈이 일과 언어를 따르도록 글자 스타일에
/// 언어를 싣는다. 화면 문구(`context.l10n`)가 읽는 `Localizations` 는 건드리지 않는다.
///
/// 글줄을 **직접** 감싸야 한다 — 사이에 `Material` 이 있으면 기본 글자 스타일이 다시 정해져 값이 사라진다.
class ContentLocale extends StatelessWidget {
  const ContentLocale({super.key, required this.language, required this.child});

  /// 일과 언어 코드(`ko` `en` `ja` `zh` `es`). 모르는 값은 `ko`.
  final String? language;
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(locale: contentLocaleOf(language)),
    child: child,
  );
}
