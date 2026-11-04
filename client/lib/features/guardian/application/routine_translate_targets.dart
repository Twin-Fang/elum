import '../../../core/l10n/app_locales.dart';
import '../../../core/l10n/content_locale.dart';
import '../../../shared/models/routine.dart';

/// 다른 언어로 만들기의 고를 수 있는 언어: 앱이 여는 언어 중 이 일과 언어가 아닌 것 (서버 대상 목록과 같음)
List<String> routineTranslateTargetsOf(Routine routine) {
  final sourceLanguage = normalizeContentLanguage(routine.language);
  return [
    for (final locale in openedAppLocales)
      if (locale.languageCode != sourceLanguage) locale.languageCode,
  ];
}
