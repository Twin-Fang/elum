import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 광고 코드를 import할 수 있는 화면은 이 셋뿐이다.
///
/// 이룸이 화면·일과 만들기 흐름·보상 연출·온보딩에 광고가 생기면 되돌릴 방법을
/// 모르는 사용자가 잘못 누른다. 실수로 import가 늘면 이 테스트가 실패한다.
void main() {
  Iterable<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('core/ads를 쓰는 화면은 보호자 홈·임시저장·설정뿐이다', () {
    const allowed = {
      'lib/features/guardian/presentation/guardian_home_screen.dart',
      'lib/features/guardian/presentation/guardian_settings_screen.dart',
      'lib/features/guardian/presentation/draft_routines_screen.dart',
    };
    final users = dartFiles('lib')
        .where((f) => !f.path.startsWith('lib/core/ads/'))
        // 설정값을 읽어 주는 AppConfig 는 화면이 아니다.
        .where((f) => f.path != 'lib/core/config/app_config.dart')
        .where((f) => f.readAsStringSync().contains('core/ads/'))
        .map((f) => f.path)
        .toSet();
    expect(users, allowed);
  });

  test('이룸이 화면 폴더는 광고를 전혀 모른다', () {
    final offenders = dartFiles('lib/features/child')
        .where(
          (f) => f.readAsStringSync().contains(
            RegExp(r'core/ads|google_mobile_ads'),
          ),
        )
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });

  test('google_mobile_ads는 core/ads 안에서만 쓴다', () {
    final offenders = dartFiles('lib')
        .where((f) => !f.path.startsWith('lib/core/ads/'))
        .where((f) => f.readAsStringSync().contains('google_mobile_ads'))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });

  test('광고 요청에 사용자 정보를 넘기지 않는다', () {
    final src = File('lib/core/ads/ad_banner_loader.dart').readAsStringSync();
    expect(src, isNot(contains('keywords')));
    expect(src, isNot(contains('contentUrl')));
    expect(src, contains('AdRequest(nonPersonalizedAds:'));
  });
}
