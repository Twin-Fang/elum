import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 광고 코드를 import할 수 있는 화면은 홈·임시저장뿐이다(보상형 흐름은 홈이 부른다).
/// 설정은 `회원탈퇴` 줄과 가까워 뺐다.
///
/// 이룸이 화면·일과 만들기 흐름·보상 연출·온보딩에 광고가 생기면 되돌릴 방법을
/// 모르는 사용자가 잘못 누른다. 실수로 import가 늘면 이 테스트가 실패한다.
void main() {
  Iterable<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('core/ads를 쓰는 화면은 보호자 홈·임시저장뿐이다', () {
    const allowed = {
      // 앱 시작 때 ATT 팝업을 묻는다(#519). 광고를 그리지 않고 AdConsent.requestOnLaunch 만 부른다.
      'lib/app.dart',
      'lib/features/guardian/presentation/guardian_home_screen.dart',
      'lib/features/guardian/presentation/draft_routines_screen.dart',
      // 홈 크레딧 소진 안내(#464)가 부르는 보상형 흐름. 아래 테스트가 호출처를 홈 하나로 잠근다.
      'lib/features/credit/application/ad_reward_flow.dart',
      // 홈 '지난 일과' 목록 사이 네이티브 광고(#465). 아래 테스트가 지난 일과 구역 안으로 잠근다.
      'lib/features/guardian/presentation/widgets/today_routine_section.dart',
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
    // 배너·네이티브·보상형 모두 — 요청을 만드는 모든 로더가 같은 모양이어야 한다.
    for (final name in [
      'ad_banner_loader.dart',
      'rewarded_ad_loader.dart',
      'ad_native_loader.dart',
    ]) {
      final src = File('lib/core/ads/$name').readAsStringSync();
      expect(src, isNot(contains('keywords')), reason: name);
      expect(src, isNot(contains('contentUrl')), reason: name);
      expect(src, isNot(contains('customTargeting')), reason: name);
      expect(src, contains('AdRequest(nonPersonalizedAds:'), reason: name);
    }
  });

  // 보상형은 "일과 만들기 진입 전" 안내에서만 제안한다 (#464, 설계 §2·§7).
  // 일과 만들기 흐름·이룸이 화면·보상·완료 연출·온보딩이 이 흐름을 알면 안 된다.
  test('광고 보고 더 만들기는 홈의 크레딧 소진 안내에서만 부른다', () {
    final callers = dartFiles('lib')
        .where((f) => !f.path.startsWith('lib/features/credit/'))
        .where(
          (f) => f.readAsStringSync().contains(
            RegExp(r'ad_reward_|credit_blocked_dialog|rewarded_ad_loader'),
          ),
        )
        .map((f) => f.path)
        .toSet();
    expect(callers, {
      'lib/features/guardian/presentation/guardian_home_screen.dart',
    });
  });

  test('credit 안에서도 보상형 흐름은 안내 팝업만 부른다', () {
    Set<String> importers(String name) => dartFiles('lib/features/credit')
        .where(
          (f) => f.readAsStringSync().contains(RegExp("import '[^']*$name")),
        )
        .map((f) => f.path)
        .toSet();

    expect(importers('ad_reward_flow'), {
      'lib/features/credit/presentation/credit_blocked_dialog.dart',
    });
    expect(importers('rewarded_ad_loader'), {
      'lib/features/credit/application/ad_reward_flow.dart',
    });
  });

  // 한 파일에 오늘·지난 일과 구역이 함께 있어, 파일 단위로는 오늘 일과에 끼었는지 못 가린다.
  test('네이티브 광고는 지난 일과 구역에서만 쓴다', () {
    final users = dartFiles('lib')
        .where((f) => !f.path.startsWith('lib/core/ads/'))
        .where((f) => f.readAsStringSync().contains('AdNativeSlot'))
        .map((f) => f.path)
        .toSet();
    expect(users, {
      'lib/features/guardian/presentation/widgets/today_routine_section.dart',
    });

    final src = File(users.single).readAsStringSync();
    final pastStart = src.indexOf('class PastRoutineSection');
    expect(pastStart, greaterThan(0));
    // 지난 일과 구역 앞(오늘 일과·공용 위젯)에는 슬롯이 없다.
    expect(src.substring(0, pastStart), isNot(contains('AdNativeSlot(')));
    expect(src.substring(pastStart), contains('AdNativeSlot('));
  });
}
