import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/guide_tip.dart';

/// 사이트 언어 중 주소 앞부분이 없는 언어 (루트 `/`, site/site_config.py `LANGUAGES`)
const _siteRootLanguageCode = 'ko';

/// 사이트가 `/<언어>/` 로 여는 언어. 그 밖의 앱 언어는 영어 글로 보냄
const _sitePrefixedLanguageCodes = {'en', 'ja', 'zh', 'es'};
const _siteFallbackLanguageCode = 'en';

/// 앱 언어 > 안내 글 주소: 한국어 `{사이트}/guide/{slug}/`, 그 외 `{사이트}/{언어}/guide/{slug}/`
Uri toGuideArticleUrl(GuideTip tip, String languageCode) {
  final String languagePrefix;
  if (languageCode == _siteRootLanguageCode) {
    languagePrefix = '';
  } else if (_sitePrefixedLanguageCodes.contains(languageCode)) {
    languagePrefix = '$languageCode/';
  } else {
    languagePrefix = '$_siteFallbackLanguageCode/';
  }
  return Uri.parse('${AppConfig.siteBaseUrl}${languagePrefix}guide/${tip.slug}/');
}

/// 닫은 가이드 팁 slug 모음: 닫으면 모든 자리에서 다시 안 보임 (기기 범위 저장)
class DismissedGuideTipsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.read(localStorageProvider).dismissedGuideTipSlugs.toSet();

  /// 닫기(x): 화면에서 먼저 숨기고 저장
  Future<void> dismiss(GuideTip tip) async {
    if (state.contains(tip.slug)) return;
    state = {...state, tip.slug};
    try {
      await ref.read(localStorageProvider).setDismissedGuideTipSlugs(state.toList());
    } catch (error, stack) {
      // 안내용 기록이라 저장 실패로 화면을 막지 않음 (이번 실행에서는 숨김 유지)
      AppLogger.error('[guide tip] dismiss save failed', error, stack, {'slug': tip.slug});
    }
  }
}

final dismissedGuideTipsProvider = NotifierProvider<DismissedGuideTipsNotifier, Set<String>>(
  DismissedGuideTipsNotifier.new,
);

/// 자리 하나에 지금 보일 팁 (없으면 null)
final guideTipForPlacementProvider = Provider.autoDispose.family<GuideTip?, GuideTipPlacement>((ref, placement) {
  return placement.firstVisibleTip(ref.watch(dismissedGuideTipsProvider));
});
