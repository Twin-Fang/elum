# AdMob 기반 + 배너 구현 계획 (#281 단계 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 보호자 홈·임시저장·설정에 하단 배너를 붙이는 기반(SDK·ATT·게이트·테스트 ID 강제·네이티브 설정)을 만든다.

**Architecture:** `lib/core/ads/`에 광고 단위 ID 해석(`AdIds`), 로더 인터페이스(`AdBannerLoader`), 동의 결정(`AdConsent`), 게이트(`adsEnabledProvider`), 화면용 위젯(`AdBannerSlot`)을 둔다. 슬롯은 로드 전·실패 시 높이 0이라 자리를 차지하지 않는다. 호스트(macOS) 위젯 테스트에서는 게이트가 false라 SDK를 건드리지 않는다.

**Tech Stack:** Flutter 3.38 · Riverpod 3 · `google_mobile_ads ^7.0.0`(9.x는 Xcode 26 미만 iOS 빌드 실패) · `app_tracking_transparency ^2.0.7` · Android manifestPlaceholders · iOS xcconfig

**Spec:** `docs/superpowers/specs/2026-09-30-admob-ads-design.md` (단계 1만 다룬다. 네이티브·보상형·서버 설정은 #463~#465)

## Global Constraints

- 개발·디버그·프로필·테스트 빌드(`kDebugMode || AppConfig.isDevBuild`)는 **Google 공식 테스트 광고 단위 ID만** 쓴다. 실제 ID를 코드·저장소에 넣지 않는다.
- 이룸이 화면(`lib/features/child/`)·일과 만들기 흐름·보상 연출·온보딩·연결·비밀암호 변경 화면은 `core/ads`를 import하지 않는다.
- 광고 요청에는 `AdRequest(nonPersonalizedAds: …)` 외 사용자 정보를 넘기지 않는다(키워드·콘텐츠 URL·이룸이 정보 없음).
- 로드 실패·미지원 환경에서 빈 자리를 남기지 않는다(높이 0).
- 화면 문구에 "아이"를 쓰지 않는다(이룸이). 해요체·능동형.
- 코드 주석은 간결한 한국어로 WHY 중심.
- 커밋은 `/pro-commit`, push·배포·git add -A 금지. 다른 세션의 변경은 건드리지 않는다.

## Review Focus

- 앱 ID가 비면 SDK가 시작하다 죽는다 → 네이티브 기본값은 Google 테스트 앱 ID (Task 2).
- ATT 팝업·SDK 초기화 예외로 화면이 죽는다 → 로더가 예외를 삼키지 않고 로그를 남긴 뒤 null을 돌려준다 (Task 3).
- 광고가 로드된 뒤 화면을 떠나면 광고 객체가 남는다 → `dispose`에서 해제 (Task 3).
- `bottomButton`과 `bottomBanner`를 함께 쓰면 하단 버튼을 가린다 → assert (Task 4).
- 폭이 0인 첫 프레임에서 적응형 배너를 요청하면 예외 → 폭이 0이면 요청하지 않는다 (Task 3).

---

## File Structure

| 파일 | 책임 |
|---|---|
| `lib/core/ads/ad_ids.dart` | 배치·플랫폼별 광고 단위 ID 해석, 테스트 ID 강제 |
| `lib/core/ads/ad_consent.dart` | ATT 상태 → 비개인화 여부 |
| `lib/core/ads/ad_banner_loader.dart` | 로더 인터페이스, 실제 구현(SDK 초기화·요청), provider |
| `lib/core/ads/ad_gate.dart` | `adsEnabledProvider` |
| `lib/core/ads/ad_banner_slot.dart` | 화면용 슬롯 위젯 |
| `lib/core/widgets/elum_scaffold.dart` | `bottomBanner` 슬롯 |
| `lib/core/config/app_config.dart` | 광고 키 읽기 |
| `lib/features/guardian/presentation/{guardian_home,guardian_settings,draft_routines}_screen.dart` | 슬롯 배치 |
| `android/app/build.gradle.kts` · `AndroidManifest.xml` | 앱 ID placeholder · AD_ID 권한 |
| `ios/Runner/Info.plist` · `tool/gen_ios_secrets.sh` | `GADApplicationIdentifier` · ATT 문구 · SKAdNetwork |
| `test/ads/*` | 단위·위젯·구조 테스트 |

---

### Task 1: 의존성과 광고 단위 ID 해석

**Files:**
- Modify: `client/pubspec.yaml`
- Modify: `client/.env.example`
- Modify: `client/lib/core/config/app_config.dart`
- Create: `client/lib/core/ads/ad_ids.dart`
- Test: `client/test/ads/ad_ids_test.dart`

**Interfaces:**
- Produces: `enum AdPlacement { bannerHome, bannerDrafts, bannerSettings, nativeHomePast, rewardedCredit }`
- Produces: `String? AdIds.resolve({required AdPlacement placement, required bool isIos, required bool useTestIds, required String Function(String key) readEnv})` — 테스트 모드면 Google 테스트 ID, 아니면 `.env` 값(비면 null)
- Produces: `AppConfig.adUnitId(AdPlacement, {required bool isIos})`, `AppConfig.useTestAds`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/ads/ad_ids_test.dart`

```dart
import 'package:elum/core/ads/ad_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String env(String key) => const {
        'ELUM_ADMOB_ANDROID_BANNER_HOME': 'ca-app-pub-real/1',
        'ELUM_ADMOB_IOS_BANNER_HOME': 'ca-app-pub-real/2',
      }[key] ??
      '';

  test('테스트 모드는 .env에 실제 ID가 있어도 Google 테스트 ID만 쓴다', () {
    final android = AdIds.resolve(
      placement: AdPlacement.bannerHome,
      isIos: false,
      useTestIds: true,
      readEnv: env,
    );
    final ios = AdIds.resolve(
      placement: AdPlacement.bannerHome,
      isIos: true,
      useTestIds: true,
      readEnv: env,
    );
    expect(android, 'ca-app-pub-3940256099942544/9214589741');
    expect(ios, 'ca-app-pub-3940256099942544/2435281174');
  });

  test('릴리스 모드는 .env 값을 쓴다', () {
    expect(
      AdIds.resolve(
        placement: AdPlacement.bannerHome,
        isIos: false,
        useTestIds: false,
        readEnv: env,
      ),
      'ca-app-pub-real/1',
    );
  });

  test('릴리스 모드에서 값이 비면 null — 광고를 띄우지 않는다', () {
    expect(
      AdIds.resolve(
        placement: AdPlacement.bannerSettings,
        isIos: true,
        useTestIds: false,
        readEnv: env,
      ),
      isNull,
    );
  });

  test('모든 배치에 두 플랫폼의 테스트 ID가 있다', () {
    for (final p in AdPlacement.values) {
      for (final ios in [true, false]) {
        final id = AdIds.resolve(
          placement: p,
          isIos: ios,
          useTestIds: true,
          readEnv: (_) => '',
        );
        expect(id, startsWith('ca-app-pub-3940256099942544/'));
      }
    }
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd client && flutter test test/ads/ad_ids_test.dart`
Expected: FAIL — `ad_ids.dart`가 없다.

- [ ] **Step 3: 구현한다**

`client/lib/core/ads/ad_ids.dart`

```dart
/// 광고를 띄우는 자리. 형식이 아니라 **배치**로 나눠 광고 단위를 따로 둔다.
///
/// 배치마다 단위를 나눠 두면 콘솔에서 자리별 수익을 비교할 수 있다.
enum AdPlacement {
  bannerHome('BANNER_HOME'),
  bannerDrafts('BANNER_DRAFTS'),
  bannerSettings('BANNER_SETTINGS'),
  nativeHomePast('NATIVE_HOME_PAST'),
  rewardedCredit('REWARDED_CREDIT');

  const AdPlacement(this.envSuffix);

  /// `.env` 키의 뒷부분. `ELUM_ADMOB_{IOS|ANDROID}_{envSuffix}`.
  final String envSuffix;
}

/// 광고 단위 ID 해석.
///
/// ⚠️ **테스트 모드면 `.env`를 읽지 않는다.** 개발 중 실제 광고를 누르면 AdMob
/// 계정이 정지될 수 있다. 실수로 실제 ID가 `.env`에 있어도 개발·테스트 빌드에서는
/// 절대 쓰이지 않게 이 함수 안에서 막는다.
abstract final class AdIds {
  /// Google이 공개한 공식 테스트 광고 단위.
  static const _testIds = <AdPlacement, ({String android, String ios})>{
    AdPlacement.bannerHome: _banner,
    AdPlacement.bannerDrafts: _banner,
    AdPlacement.bannerSettings: _banner,
    AdPlacement.nativeHomePast: (
      android: 'ca-app-pub-3940256099942544/2247696110',
      ios: 'ca-app-pub-3940256099942544/3986624511',
    ),
    AdPlacement.rewardedCredit: (
      android: 'ca-app-pub-3940256099942544/5224354917',
      ios: 'ca-app-pub-3940256099942544/1712485313',
    ),
  };

  static const _banner = (
    android: 'ca-app-pub-3940256099942544/9214589741',
    ios: 'ca-app-pub-3940256099942544/2435281174',
  );

  /// 릴리스에서 값이 비어 있으면 null — 호출한 쪽은 광고를 띄우지 않는다.
  static String? resolve({
    required AdPlacement placement,
    required bool isIos,
    required bool useTestIds,
    required String Function(String key) readEnv,
  }) {
    if (useTestIds) {
      final ids = _testIds[placement]!;
      return isIos ? ids.ios : ids.android;
    }
    final key =
        'ELUM_ADMOB_${isIos ? 'IOS' : 'ANDROID'}_${placement.envSuffix}';
    final value = readEnv(key).trim();
    return value.isEmpty ? null : value;
  }
}
```

- [ ] **Step 4: `AppConfig`에 연결한다**

`client/lib/core/config/app_config.dart`의 `isDevBuild` 아래에 추가한다(파일 상단에 `import '../ads/ad_ids.dart';`).

```dart
  // --- 광고 ---

  /// 테스트 광고만 쓸지. 디버그·프로필·개발용(dev) 빌드는 항상 true다.
  ///
  /// 릴리스 빌드에서만 false라 `.env`의 실제 광고 단위를 읽는다.
  /// 개발 중 실제 광고를 누르면 AdMob 계정이 정지될 수 있다.
  static bool get useTestAds => kDebugMode || kProfileMode || isDevBuild;

  /// 배치별 광고 단위 ID. 릴리스에서 `.env`에 값이 없으면 null이다.
  static String? adUnitId(AdPlacement placement, {required bool isIos}) =>
      AdIds.resolve(
        placement: placement,
        isIos: isIos,
        useTestIds: useTestAds,
        readEnv: (key) => _string(key, ''),
      );
```

- [ ] **Step 5: 의존성과 `.env.example`**

```bash
cd client && flutter pub add google_mobile_ads app_tracking_transparency
```

`client/.env.example` 끝에 추가:

```
# --- 광고 (AdMob) ---
# 개발·디버그·테스트 빌드는 이 값과 무관하게 Google 테스트 광고만 쓴다.
# 릴리스 빌드만 아래 실제 광고 단위를 읽는다. 값이 비면 그 자리에 광고를 띄우지 않는다.
# 앱 ID는 네이티브 설정(빌드 타임)에도 쓰인다. 비면 Google 테스트 앱 ID로 뜬다.
ELUM_ADMOB_ANDROID_APP_ID=
ELUM_ADMOB_IOS_APP_ID=
ELUM_ADMOB_ANDROID_BANNER_HOME=
ELUM_ADMOB_IOS_BANNER_HOME=
ELUM_ADMOB_ANDROID_BANNER_DRAFTS=
ELUM_ADMOB_IOS_BANNER_DRAFTS=
ELUM_ADMOB_ANDROID_BANNER_SETTINGS=
ELUM_ADMOB_IOS_BANNER_SETTINGS=
```

- [ ] **Step 6: 통과 확인과 커밋 준비**

Run: `cd client && flutter test test/ads/ad_ids_test.dart && flutter analyze lib/core`
Expected: PASS, analyze 0건. 커밋은 마지막에 `/pro-commit`으로 한 번에 한다(스테이징은 아래 경로만).

---

### Task 2: 네이티브 설정 (Android · iOS)

**Files:**
- Modify: `client/android/app/build.gradle.kts`
- Modify: `client/android/app/src/main/AndroidManifest.xml`
- Modify: `client/ios/Runner/Info.plist`
- Modify: `client/tool/gen_ios_secrets.sh`
- Test: `client/test/ads/native_ad_config_test.dart`

**Interfaces:**
- Consumes: `.env`의 `ELUM_ADMOB_ANDROID_APP_ID`, `ELUM_ADMOB_IOS_APP_ID`
- Produces: Android `${admobAppId}` placeholder, iOS `$(ELUM_ADMOB_APP_ID)` 빌드 설정

- [ ] **Step 1: 실패하는 테스트를 쓴다** (기존 `android_naver_login_manifest_test.dart` 방식)

`client/test/ads/native_ad_config_test.dart`

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 앱 ID가 비면 SDK가 시작하다 앱이 죽는다. 네이티브 설정이 빠지면 바로 알린다.
void main() {
  test('Android 매니페스트에 광고 앱 ID와 광고 ID 권한이 있다', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('com.google.android.gms.ads.APPLICATION_ID'));
    expect(manifest, contains(r'${admobAppId}'));
    expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
  });

  test('Android 빌드가 앱 ID를 .env에서 읽고 비면 테스트 앱 ID를 쓴다', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('admobAppId'));
    expect(gradle, contains('ca-app-pub-3940256099942544~3347511713'));
  });

  test('iOS Info.plist에 광고 앱 ID·추적 안내 문구·SKAdNetwork가 있다', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('GADApplicationIdentifier'));
    expect(plist, contains(r'$(ELUM_ADMOB_APP_ID)'));
    expect(plist, contains('NSUserTrackingUsageDescription'));
    expect(plist, contains('SKAdNetworkItems'));
    expect(plist, isNot(contains('아이')));
  });

  test('iOS 시크릿 생성 스크립트가 앱 ID를 만들고 비면 테스트 앱 ID를 쓴다', () {
    final script = File('tool/gen_ios_secrets.sh').readAsStringSync();
    expect(script, contains('ELUM_ADMOB_APP_ID'));
    expect(script, contains('ca-app-pub-3940256099942544~1458002511'));
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd client && flutter test test/ads/native_ad_config_test.dart`
Expected: FAIL 4건.

- [ ] **Step 3: Android를 설정한다**

`build.gradle.kts`의 `manifestPlaceholders["kakaoScheme"]` 아래에 추가:

```kotlin
        // AdMob 앱 ID. 비면 SDK가 시작하다 죽으므로 Google 테스트 앱 ID를 기본값으로 둔다.
        manifestPlaceholders["admobAppId"] =
            env("ELUM_ADMOB_ANDROID_APP_ID").ifEmpty { "ca-app-pub-3940256099942544~3347511713" }
```

`AndroidManifest.xml`의 `INTERNET` 권한 아래에 추가:

```xml
    <!-- 광고 ID. Android 13(API 33)+에서 선언하지 않으면 광고 식별자가 0으로 나와 단가가 떨어진다. -->
    <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
```

`<application>` 안 네이버 meta-data 뒤에 추가:

```xml
        <!-- AdMob 앱 ID. 값은 build.gradle.kts가 .env로 채운다. -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="${admobAppId}"/>
```

- [ ] **Step 4: iOS를 설정한다**

`tool/gen_ios_secrets.sh`에서 `GOOGLE_IOS_ID=` 읽는 줄 아래에:

```bash
# 비면 SDK가 시작하다 죽으므로 Google 테스트 앱 ID를 기본값으로 둔다.
ADMOB_APP_ID="$(read_env ELUM_ADMOB_IOS_APP_ID)"
[ -z "$ADMOB_APP_ID" ] && ADMOB_APP_ID="ca-app-pub-3940256099942544~1458002511"
```

그리고 heredoc 마지막 줄 `ELUM_GOOGLE_REVERSED_CLIENT_ID=...` 아래에 `ELUM_ADMOB_APP_ID=${ADMOB_APP_ID}`를 추가한다.

`Info.plist`의 `NidAppName` 다음(닫는 `</dict>` 앞)에 추가:

```xml
	<!-- AdMob 앱 ID. 값은 ios/Flutter/Secrets.xcconfig가 채운다. -->
	<key>GADApplicationIdentifier</key>
	<string>$(ELUM_ADMOB_APP_ID)</string>
	<!-- 추적 허용 팝업에 뜨는 안내. 이룸이 정보는 쓰지 않는다는 점을 함께 알린다. -->
	<key>NSUserTrackingUsageDescription</key>
	<string>보호자 화면에 알맞은 광고를 보여드리는 데 사용해요. 이룸이의 정보는 사용하지 않아요.</string>
	<!-- Google 권장 SKAdNetwork 식별자. 광고 성과 측정에 쓰여 단가에 영향을 준다. -->
	<key>SKAdNetworkItems</key>
	<array>
		<dict>
			<key>SKAdNetworkIdentifier</key>
			<string>cstr6suwn9.skadnetwork</string>
		</dict>
	</array>
```

(전체 식별자 목록은 Google 공식 안내의 최신본으로 채운다. 위는 Google 자신의 식별자다.)

- [ ] **Step 5: 통과 확인**

Run: `cd client && flutter test test/ads/native_ad_config_test.dart && bash tool/gen_ios_secrets.sh && grep ELUM_ADMOB ios/Flutter/Secrets.xcconfig`
Expected: PASS, 테스트 앱 ID가 출력된다(로컬 `.env`에 값이 없으므로).

---

### Task 3: 동의 · 게이트 · 로더 · 슬롯

**Files:**
- Create: `client/lib/core/ads/ad_consent.dart`
- Create: `client/lib/core/ads/ad_gate.dart`
- Create: `client/lib/core/ads/ad_banner_loader.dart`
- Create: `client/lib/core/ads/ad_banner_slot.dart`
- Test: `client/test/ads/ad_banner_slot_test.dart`

**Interfaces:**
- Consumes: `AdPlacement`, `AppConfig.adUnitId`
- Produces: `class LoadedBanner { LoadedBanner({required this.height, required this.widget, required this.dispose}); final double height; final Widget widget; final VoidCallback dispose; }`
- Produces: `abstract interface class AdBannerLoader { Future<LoadedBanner?> load(AdPlacement placement, int widthDp); }`
- Produces: `final adBannerLoaderProvider = Provider<AdBannerLoader>`, `final adsEnabledProvider = Provider<bool>`
- Produces: `AdBannerSlot({required AdPlacement placement})`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/ads/ad_banner_slot_test.dart`

```dart
import 'dart:async';

import 'package:elum/core/ads/ad_banner_loader.dart';
import 'package:elum/core/ads/ad_banner_slot.dart';
import 'package:elum/core/ads/ad_gate.dart';
import 'package:elum/core/ads/ad_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLoader implements AdBannerLoader {
  _FakeLoader(this.results);

  /// 호출 순서대로 돌려줄 결과. null은 실패.
  final List<LoadedBanner?> results;
  var calls = 0;
  var disposed = 0;
  int? lastWidth;

  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) async {
    lastWidth = widthDp;
    final r = calls < results.length ? results[calls] : null;
    calls++;
    return r;
  }
}

Widget _host(_FakeLoader loader, {bool enabled = true}) => ProviderScope(
      overrides: [
        adBannerLoaderProvider.overrideWithValue(loader),
        adsEnabledProvider.overrideWithValue(enabled),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: Text('본문')),
              AdBannerSlot(placement: AdPlacement.bannerHome),
            ],
          ),
        ),
      ),
    );

LoadedBanner _banner(_FakeLoader l) => LoadedBanner(
      height: 60,
      widget: const SizedBox(key: Key('배너'), height: 60),
      dispose: () => l.disposed++,
    );

void main() {
  testWidgets('로드 전에는 자리를 차지하지 않는다', (tester) async {
    final completer = Completer<LoadedBanner?>();
    final loader = _PendingLoader(completer.future);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        adBannerLoaderProvider.overrideWithValue(loader),
        adsEnabledProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AdBannerSlot(placement: AdPlacement.bannerHome)),
      ),
    ));
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 0);
  });

  testWidgets('로드에 성공하면 그 높이만큼 자리를 차지한다', (tester) async {
    final loader = _FakeLoader([]);
    loader.results.add(_banner(loader));
    await tester.pumpWidget(_host(loader));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('배너')), findsOneWidget);
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 60);
  });

  testWidgets('실패하면 높이 0으로 남고 30초·60초 뒤 한 번씩만 다시 시도한다', (tester) async {
    final loader = _FakeLoader([null, null, null, null]);
    await tester.pumpWidget(_host(loader));
    await tester.pumpAndSettle();
    expect(loader.calls, 1);
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 0);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(loader.calls, 2);

    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(loader.calls, 3);

    // 더는 시도하지 않는다.
    await tester.pump(const Duration(minutes: 10));
    expect(loader.calls, 3);
  });

  testWidgets('게이트가 꺼져 있으면 로드하지 않는다', (tester) async {
    final loader = _FakeLoader([]);
    await tester.pumpWidget(_host(loader, enabled: false));
    await tester.pumpAndSettle();
    expect(loader.calls, 0);
    expect(tester.getSize(find.byType(AdBannerSlot)).height, 0);
  });

  testWidgets('화면을 떠나면 광고를 해제한다', (tester) async {
    final loader = _FakeLoader([]);
    loader.results.add(_banner(loader));
    await tester.pumpWidget(_host(loader));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(loader.disposed, 1);
  });

  testWidgets('로드가 늦게 끝나도 이미 떠난 화면에는 그리지 않고 해제한다', (tester) async {
    final completer = Completer<LoadedBanner?>();
    final loader = _PendingLoader(completer.future);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        adBannerLoaderProvider.overrideWithValue(loader),
        adsEnabledProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AdBannerSlot(placement: AdPlacement.bannerHome)),
      ),
    ));
    await tester.pumpWidget(const SizedBox());
    var disposed = 0;
    completer.complete(LoadedBanner(
      height: 50,
      widget: const SizedBox(),
      dispose: () => disposed++,
    ));
    await tester.pump();
    expect(disposed, 1);
  });

  testWidgets('로더가 예외를 던져도 화면은 살아 있다', (tester) async {
    final loader = _ThrowingLoader();
    await tester.pumpWidget(_host(loader as dynamic));
    await tester.pumpAndSettle();
    expect(find.text('본문'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PendingLoader implements AdBannerLoader {
  _PendingLoader(this.future);
  final Future<LoadedBanner?> future;
  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) => future;
}

class _ThrowingLoader extends _FakeLoader {
  _ThrowingLoader() : super([]);
  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) =>
      Future.error(StateError('sdk'));
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd client && flutter test test/ads/ad_banner_slot_test.dart`
Expected: FAIL — 파일이 없다.

- [ ] **Step 3: 게이트와 동의를 구현한다**

`client/lib/core/ads/ad_gate.dart`

```dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 광고를 띄울 수 있는 환경인가.
///
/// 지금은 모바일이면 전원에게 켜진다(Free 기본). 나중에 `FREE_ADS_REMOVED`·
/// `PRO_ADS_REMOVED`를 이 한 곳에 연결한다. 호스트(macOS) 위젯 테스트는
/// 모바일이 아니라 자동으로 꺼져 SDK를 건드리지 않는다.
final adsEnabledProvider = Provider<bool>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);
```

`client/lib/core/ads/ad_consent.dart`

```dart
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import '../logger/app_logger.dart';

/// 광고를 개인화해서 요청할지 정한다.
///
/// iOS는 추적 권한을 **먼저 물어야** 한다(심사 4.0). 안 물으면 리젝이다.
/// 거부하거나 물을 수 없으면 비개인화로 요청한다 — 앱은 그대로 동작한다.
/// Android는 ATT가 없어 개인화 기본이다.
abstract final class AdConsent {
  /// true면 비개인화 광고로 요청한다.
  static Future<bool> useNonPersonalized() async {
    if (!Platform.isIOS) return false;
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // 앱이 완전히 활성화되기 전에 요청하면 팝업이 뜨지 않는 경우가 있어 잠깐 기다린다.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      return status != TrackingStatus.authorized;
    } catch (e, st) {
      // 물을 수 없어도 광고는 비개인화로 진행한다. 조용히 삼키지 않고 남긴다.
      AppLogger.error('ATT 요청 실패', e, st);
      return true;
    }
  }
}
```

(`AppLogger.error`의 실제 시그니처를 `lib/core/logger/app_logger.dart`에서 확인해 맞춘다.)

- [ ] **Step 4: 로더를 구현한다**

`client/lib/core/ads/ad_banner_loader.dart`

```dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import '../logger/app_logger.dart';
import 'ad_consent.dart';
import 'ad_ids.dart';

/// 로드가 끝난 배너. 슬롯이 그리고 화면을 떠날 때 [dispose]로 해제한다.
class LoadedBanner {
  LoadedBanner({
    required this.height,
    required this.widget,
    required this.dispose,
  });

  final double height;
  final Widget widget;
  final VoidCallback dispose;
}

/// 배너를 불러온다. 테스트는 이것을 가짜로 바꿔 SDK를 띄우지 않는다.
abstract interface class AdBannerLoader {
  /// 실패·미지원이면 null. **예외를 던지지 않는다.**
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp);
}

final adBannerLoaderProvider = Provider<AdBannerLoader>(
  (ref) => GoogleAdBannerLoader(),
);

/// google_mobile_ads 구현.
///
/// SDK는 **처음 배너를 요청할 때** 초기화한다. 이룸이 전용 휴대폰은 보호자 화면을
/// 열지 않으므로 SDK가 시작되지도 않는다.
class GoogleAdBannerLoader implements AdBannerLoader {
  static Future<void>? _init;

  static Future<void> _ensureInitialized() => _init ??= () async {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            // 성인·선정 광고를 줄인다. 보호자 화면이라도 이룸이가 볼 수 있다.
            maxAdContentRating: MaxAdContentRating.pg,
          ),
        );
        await MobileAds.instance.initialize();
      }();

  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) async {
    // 폭 0에서 적응형 배너를 요청하면 예외가 난다(첫 프레임).
    if (widthDp <= 0) return null;
    try {
      final unitId = AppConfig.adUnitId(placement, isIos: Platform.isIOS);
      if (unitId == null) return null; // 릴리스인데 .env가 비었다 — 광고를 띄우지 않는다.

      await _ensureInitialized();
      final nonPersonalized = await AdConsent.useNonPersonalized();
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        widthDp,
      );
      if (size == null) return null;

      final done = Completer<BannerAd?>();
      final ad = BannerAd(
        adUnitId: unitId,
        size: size,
        // 요청에 넘기는 것은 비개인화 여부뿐이다. 이룸이·보호자 정보는 넘기지 않는다.
        request: AdRequest(nonPersonalizedAds: nonPersonalized),
        listener: BannerAdListener(
          onAdLoaded: (a) => done.complete(a as BannerAd),
          onAdFailedToLoad: (a, error) {
            AppLogger.error('배너 로드 실패 ${placement.name}', error);
            a.dispose();
            done.complete(null);
          },
        ),
      );
      await ad.load();
      final loaded = await done.future;
      if (loaded == null) return null;
      return LoadedBanner(
        height: size.height.toDouble(),
        widget: SizedBox(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          child: AdWidget(ad: loaded),
        ),
        dispose: loaded.dispose,
      );
    } catch (e, st) {
      // 광고는 보조 요소라 사용자에게 알리지 않는다. 다만 삼키지 않고 남긴다.
      AppLogger.error('배너 준비 실패 ${placement.name}', e, st);
      return null;
    }
  }
}
```

(`AppLogger.error`의 시그니처가 다르면 맞춘다. `AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize`는 google_mobile_ads 9.1.0 문서로 확인한다.)

- [ ] **Step 5: 슬롯을 구현한다**

`client/lib/core/ads/ad_banner_slot.dart`

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_banner_loader.dart';
import 'ad_gate.dart';
import 'ad_ids.dart';

/// 화면 하단에 놓는 배너 자리.
///
/// **로드 전·실패 시 높이 0이다.** 빈 자리를 남기지 않는다 — 배너가 없으면 화면이
/// 그만큼 줄어든 채로가 아니라 원래 크기 그대로다. 로드에 성공하면 그 높이만큼
/// 본문이 줄어든다(겹치지 않는다).
///
/// 실패하면 30초·60초 뒤 각 한 번만 다시 시도하고 그만둔다.
class AdBannerSlot extends ConsumerStatefulWidget {
  const AdBannerSlot({super.key, required this.placement});

  final AdPlacement placement;

  @override
  ConsumerState<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends ConsumerState<AdBannerSlot> {
  static const _retryDelays = [Duration(seconds: 30), Duration(seconds: 60)];

  LoadedBanner? _banner;
  Timer? _retry;
  var _attempt = 0;
  var _disposed = false;
  var _loading = false;
  int _width = 0;

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _banner != null || _disposed) return;
    _loading = true;
    LoadedBanner? result;
    try {
      result = await ref
          .read(adBannerLoaderProvider)
          .load(widget.placement, _width);
    } catch (_) {
      // 로더가 예외를 던져도 화면은 살아 있어야 한다. 실패로 취급한다.
      result = null;
    }
    _loading = false;
    if (_disposed) {
      // 늦게 끝났는데 화면이 이미 없다 — 그리지 않고 해제한다.
      result?.dispose();
      return;
    }
    if (result != null) {
      setState(() => _banner = result);
      return;
    }
    if (_attempt < _retryDelays.length) {
      _retry = Timer(_retryDelays[_attempt++], _load);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsEnabledProvider)) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.floor()
            : MediaQuery.sizeOf(context).width.floor();
        if (width > 0 && width != _width) {
          _width = width;
          // 빌드 도중 상태를 바꾸지 않게 첫 프레임 뒤로 미룬다.
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        }
        final banner = _banner;
        if (banner == null) return const SizedBox.shrink();
        return SizedBox(
          height: banner.height,
          width: double.infinity,
          child: Center(child: banner.widget),
        );
      },
    );
  }
}
```

- [ ] **Step 6: 통과 확인**

Run: `cd client && flutter test test/ads/ad_banner_slot_test.dart && flutter analyze lib/core/ads test/ads`
Expected: PASS(7건), analyze 0건. `_ThrowingLoader` 캐스트가 컴파일 오류면 `_host`의 인자 타입을 `AdBannerLoader`로 바꾸고 `calls`·`lastWidth` 접근을 제거한다.

---

### Task 4: 화면에 배치하고 겹침을 구조로 막는다

**Files:**
- Modify: `client/lib/core/widgets/elum_scaffold.dart`
- Modify: `client/lib/features/guardian/presentation/guardian_home_screen.dart:61-110`
- Modify: `client/lib/features/guardian/presentation/guardian_settings_screen.dart:123-135`
- Modify: `client/lib/features/guardian/presentation/draft_routines_screen.dart:56-62`
- Test: `client/test/ads/ad_placement_test.dart`

**Interfaces:**
- Consumes: `AdBannerSlot`, `AdPlacement`
- Produces: `ElumScaffold({… Widget? bottomBanner})` — `bottomButton`과 함께 쓰면 assert 실패

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/ads/ad_placement_test.dart`

```dart
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp(theme: AppTheme.light, home: child),
      );

  testWidgets('bottomBanner는 본문 아래 맨 끝에 놓이고 본문과 겹치지 않는다', (tester) async {
    await tester.pumpWidget(host(ElumScaffold(
      onBack: () {},
      bottomBanner: const SizedBox(key: Key('배너'), height: 60),
      child: const Align(
        alignment: Alignment.bottomCenter,
        child: Text('본문 맨 아래', key: Key('본문')),
      ),
    )));
    final banner = tester.getRect(find.byKey(const Key('배너')));
    final body = tester.getRect(find.byKey(const Key('본문')));
    expect(body.bottom, lessThanOrEqualTo(banner.top));
  });

  test('bottomButton과 bottomBanner를 함께 쓰면 assert로 막는다', () {
    expect(
      () => ElumScaffold(
        bottomButton: const SizedBox(),
        bottomBanner: const SizedBox(),
        child: const SizedBox(),
      ),
      throwsAssertionError,
    );
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd client && flutter test test/ads/ad_placement_test.dart`
Expected: FAIL — `bottomBanner`가 없다.

- [ ] **Step 3: `ElumScaffold`에 슬롯을 추가한다**

생성자에 `this.bottomBanner,`를 추가하고, 필드와 assert를 둔다.

```dart
  const ElumScaffold({
    super.key,
    required this.child,
    this.bottomButton,
    this.belowButton,
    this.bottomBanner,
    ...
  }) : assert(
         bottomBanner == null || (bottomButton == null && belowButton == null),
         '하단 고정 버튼과 배너를 함께 쓰면 버튼을 가린다 — 배너는 버튼이 없는 화면에만 둔다',
       );

  /// 화면 맨 아래 광고 자리. 없으면 자리도 없다.
  ///
  /// [bottomButton]과 함께 못 쓰게 assert로 막는다 — 광고가 하단 고정 버튼을 가리면
  /// 심사 4.0에서 반려된다. 값이 [AdBannerSlot]이면 로드 전·실패 시 높이 0이다.
  final Widget? bottomBanner;
```

`build`의 `belowButton` 블록 뒤(Column 마지막)에 추가:

```dart
              if (bottomBanner != null) bottomBanner!,
```

(생성자가 `const`이고 초기화 리스트가 있으므로 기존 `const ElumScaffold(` 호출부는 그대로 동작한다.)

- [ ] **Step 4: 세 화면에 배치한다**

`guardian_settings_screen.dart`와 `draft_routines_screen.dart`의 `ElumScaffold(`에 각각 추가(import `../../../core/ads/ad_banner_slot.dart`, `../../../core/ads/ad_ids.dart`):

```dart
      bottomBanner: const AdBannerSlot(placement: AdPlacement.bannerSettings),
```
```dart
      bottomBanner: const AdBannerSlot(placement: AdPlacement.bannerDrafts),
```

`guardian_home_screen.dart`의 본문을 Column으로 감싼다(SafeArea 안):

```dart
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: space.xl),
                child: Column(/* 기존 내용 그대로 */),
              ),
            ),
            // 로드 전·실패 시 높이 0이라 스크롤 영역이 원래 크기 그대로다.
            const AdBannerSlot(placement: AdPlacement.bannerHome),
          ],
        ),
      ),
```

- [ ] **Step 5: 통과 확인과 기존 테스트**

Run: `cd client && flutter test test/ads test/guardian_home_screen_test.dart test/guardian_settings_test.dart test/draft_routines_test.dart test/guardian_home_golden_test.dart`
Expected: 모두 PASS(호스트에서는 게이트가 꺼져 골든이 그대로다).

---

### Task 5: 광고가 닿으면 안 되는 곳을 테스트로 잠근다

**Files:**
- Test: `client/test/ads/ad_boundary_test.dart`

- [ ] **Step 1: 테스트를 쓴다**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 광고 코드를 import할 수 있는 화면은 이 셋뿐이다.
///
/// 이룸이 화면·일과 만들기 흐름·보상 연출·온보딩에 광고가 생기면 되돌릴 방법을
/// 모르는 사용자가 잘못 누른다. 실수로 import가 늘면 이 테스트가 실패한다.
void main() {
  test('core/ads를 쓰는 화면은 보호자 홈·임시저장·설정뿐이다', () {
    const allowed = {
      'lib/features/guardian/presentation/guardian_home_screen.dart',
      'lib/features/guardian/presentation/guardian_settings_screen.dart',
      'lib/features/guardian/presentation/draft_routines_screen.dart',
    };
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.startsWith('lib/core/ads/'))
        .where((f) => f.readAsStringSync().contains('core/ads/'))
        .map((f) => f.path)
        .toSet();
    expect(users, allowed);
  });

  test('이룸이 화면 폴더는 광고를 전혀 모른다', () {
    final offenders = Directory('lib/features/child')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.readAsStringSync().contains(RegExp(r'core/ads|google_mobile_ads')))
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
```

- [ ] **Step 2: 통과 확인**

Run: `cd client && flutter test test/ads/ad_boundary_test.dart`
Expected: PASS. (Task 4 전에 돌리면 첫 테스트가 실패하는 것이 정상이다.)

---

### Task 6: 전체 검증과 시뮬레이터 확인

- [ ] **Step 1: 전체 테스트와 분석**

Run: `cd client && flutter analyze && flutter test`
Expected: analyze 0건, 전체 통과(이전 1281건 + 새 테스트).

- [ ] **Step 2: iOS 의존성**

Run: `cd client/ios && pod install`
Expected: 성공. `pubspec_overrides.yaml`(로컬 전용) 때문에 실패하면 원인을 기록하고 사용자에게 알린다.

- [ ] **Step 3: 시뮬레이터·에뮬레이터에서 테스트 광고 확인**

`/pro-launch`로 iOS 시뮬레이터와 Android 에뮬레이터에 띄워 보호자 홈·설정·임시저장 하단에 **Google 테스트 광고**(“Test Ad” 표시)가 뜨고, 이룸이 화면에는 없음을 캡처로 확인한다. 실제 광고는 누르지 않는다. iOS는 ATT 팝업 문구를 확인한다. 오프라인에서 배너 자리가 사라지고 레이아웃이 원래대로인지 본다.

- [ ] **Step 4: 문서**

`client/docs/architecture.md`에 `core/ads` 구조와 "광고를 import할 수 있는 화면은 세 곳뿐" 규칙을 한 절로 남긴다.

- [ ] **Step 5: 커밋**

`git status`로 낯선 변경을 확인하고, 만든 경로만 명시해 스테이징한 뒤 `/pro-commit`으로 커밋한다(push 안 함). `pubspec_overrides.yaml`은 제외한다.
