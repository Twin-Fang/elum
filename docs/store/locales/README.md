# 언어별 스토어 문구와 네이티브 언어 등록

> 이슈 [#527](https://github.com/Twin-Fang/elum/issues/527) · 상위 #521 · 설계 `docs/superpowers/specs/2026-10-29-native-store-locales-design.md`
> 기준은 [`../store-listing.md`](../store-listing.md), 스토어 문구 원본은 [`../listing/`](../listing/) (#1351). 번역 용어는 [`docs/i18n/glossary.md`](../../i18n/glossary.md).

## 지금 상태 (2026-11-13)

| 언어 | 앱 화면 | OS 앱별 언어 목록 | iOS 권한 문구 | 스토어 문구 |
|---|---|---|---|---|
| ko | 열림 | 등록 | `ios/Runner/ko.lproj` | [`../listing/ko`](../listing/ko) · 배포 때 자동 업로드 |
| en | 열림 | 등록 | `ios/Runner/en.lproj` | [`../listing/en`](../listing/en) · 배포 때 자동 업로드 |
| ja | 닫힘 | 안 함 | 대기 `ios/staged_locales/ja.lproj` | [`../listing/ja`](../listing/ja) · 배포 때 자동 업로드 (검색 노출용, #1351) |
| zh (간체) | 닫힘 | 안 함 | 대기 `ios/staged_locales/zh-Hans.lproj` | [`../listing/zh`](../listing/zh) · 같음 |
| es | 닫힘 | 안 함 | 대기 `ios/staged_locales/es.lproj` | [`../listing/es`](../listing/es) · 같음 |

- 스토어 문구 원본은 `../listing/<언어>/` 다(#1351). 예전 초안(`en.md` 등)은 원본으로 옮기고 지웠다.
- ja·zh·es 는 **스토어 문구만 먼저** 올린다. 그 나라 검색에 걸리게 하려는 것이고, 앱을 열면 영어 화면이 뜬다. 번역은 원어민 검수 전이다.
- 앱 이름(홈 화면)은 모든 언어에서 `이룸` 이다. 스토어 이름은 `ELUM` + 그 나라 검색어로 쓴다.

## 업로드 경로

| 파일 | 누가 올리나 | 결과 |
|---|---|---|
| `client/ios/fastlane/metadata/<로케일>/*.txt` | iOS 배포 `store_prepare`·`store_submit` 의 `deliver` (`skip_metadata: false`) | 이름·부제·키워드·설명·프로모션 문구·방침 주소·새로운 기능. 생성: `docs/store/build_store_metadata.py`. `DELIVER_LOCALES`(기본 `ko`)만 새로운 기능을 CHANGELOG 로 덧쓴다 |
| `client/ios/fastlane/review_notes.txt` | 같은 `deliver` | 심사 노트(Notes)를 매번 덮어쓴다. 레포가 원본 |
| `client/android/fastlane/metadata/android/<로케일>/*.txt` | Play 배포 `upload_to_play_store` (`skip_upload_metadata: false`) | 제목·간단한 설명·자세한 설명. 생성: 같은 스크립트 |
| `client/android/fastlane/metadata/android/ko-KR/changelogs/` | 같은 Play 배포 | 출시 노트. 워크플로가 `ko-KR` 만 만든다 |

생성본은 손으로 고치지 않는다. 원본을 고치고 스크립트를 돌린다.

## 로케일 코드

| 앱 언어 | iOS lproj · `CFBundleLocalizations` | Android `locales_config` | Android 리소스 폴더 | App Store Connect | Play |
|---|---|---|---|---|---|
| ko | `ko` | `ko` | `values-ko` | `ko` | `ko-KR` |
| en | `en` | `en` | `values-en` | `en-US` | `en-US` |
| ja | `ja` | `ja` | `values-ja` | `ja` | `ja-JP` |
| zh | `zh-Hans` | `zh-Hans` | `values-b+zh+Hans` | `zh-Hans` | `zh-CN` |
| es | `es` | `es` | `values-es` | `es-ES` 또는 `es-MX` | `es-ES` 또는 `es-419` |

- 중국어는 간체만. `values-zh-rCN` 은 싱가포르 등 다른 간체 지역을 놓친다.
- 스페인어 스토어 변종(스페인·중남미)은 정하지 않았다. 초안은 중남미에도 통하는 중립 문장(`tú`)으로 썼다.
- `ko-KR` 은 App Store Connect 코드가 아니다(`ko`).

## 글자 수 한도

| 필드 | App Store | Play |
|---|---|---|
| 이름 | 30 | 30 |
| 부제 | 30 | — |
| 간단한 설명 | — | 80 |
| 키워드 | 100 (쉼표 포함) | — |
| 프로모션 텍스트 | 170 | — |
| 자세한 설명 | 4000 | 4000 |
| 출시 노트 | 4000 | 500 |

초안마다 글자 수를 적어 두었다. 번역을 고치면 다시 센다.

## 언어를 여는 순서

앱 화면을 여는 일(ARB 번역, `openedAppLocales`)과 함께 한 PR 에서 한다. 일부만 하면 `tool/check_native_locales.dart` 가 CI 에서 실패한다.

1. `client/lib/core/l10n/app_locales.dart` 의 `openedAppLocales` 에 한 줄 더한다.
2. iOS: `client/ios/staged_locales/<lproj>` 를 `client/ios/Runner/` 로 옮기고 Xcode 에서 `InfoPlist.strings` 의 Localization 에 그 언어를 켠다(`project.pbxproj` 의 `knownRegions` 와 variant 가 생긴다). `Info.plist` 의 `CFBundleLocalizations` 에 코드를 더한다.
3. Android: `res/xml/locales_config.xml` 에 `<locale android:name="..."/>` 를 더한다.
4. `cd client && dart run tool/check_native_locales.dart` 가 0건인지 본다.
5. 스토어: 문구는 이미 `../listing/<언어>/` 로 올라가 있다. 원어민 검수를 반영하고, 그 언어 스크린샷을 넣고, 새로운 기능을 CHANGELOG 로 쓰려면 `DELIVER_LOCALES` 와 Android 출시 노트 폴더를 그 PR 에서 함께 고친다.
6. 심사 노트(`review_notes.txt`)의 언어 문장에 그 언어를 더한다.

## 심사 노트와 언어

심사자 기기는 보통 영어다. 앱은 en 을 열었으므로 영어 기기에서 영어로 뜬다. 그래서 심사 노트는

- 앱이 기기 언어를 따라 한국어·영어로 뜬다고 적고,
- 버튼 이름은 영어 ARB(`app_en.arb`) 값을 쓰고 한국어를 괄호로 곁들인다. 예: `"Log in with Apple" (Apple로 로그인)`.

화면 문구를 바꾸면 노트에 인용한 버튼 이름도 맞춘다.

## 앱별 언어 — 알려진 한계

앱 안에는 언어 선택 화면이 없다(#521). 언어는 OS 설정에서 바꾼다.

- iOS: 설정 > 이룸 > 언어. 목록은 번들의 lproj 와 `CFBundleLocalizations` 가 정한다. 대기 언어를 `Runner/` 에 넣는 순간 목록과 App Store 언어 표시에 뜬다.
- Android 13 이상: 설정 > 앱 > 이룸 > 언어. 목록은 `locales_config.xml` 이 정한다.
- **Android 12 이하에는 OS 의 앱별 언어가 없다.** `locales_config.xml` 은 무시되고 기기 언어를 바꿔야 앱 언어가 바뀐다.
- 연 언어 밖의 기기 언어는 영어 화면으로 뜬다(#521). iOS 권한 문구도 개발 언어(en)로 떨어진다.
- Android 리소스 용량을 줄이려고 `localeFilters`(`resourceConfigurations`)를 넣게 되면 연 언어를 모두 넣는다.

## 실기기 확인 절차 (사람이 한다)

빌드: 이 변경이 들어간 테스트 빌드(이슈에 `@projectops app build <브랜치>` 댓글).

| 기기 | 확인 |
|---|---|
| iPhone·iPad (iOS 17+) | 설정 > 이룸 > 언어에 `한국어`·`English` 두 개만 뜬다. English 를 고르면 앱 화면이 영어, 카메라·사진 권한 창이 영어다. 한국어로 돌리면 둘 다 한국어다 |
| iPhone 기기 언어 일본어 | 앱 화면은 영어, 권한 창도 영어다(일본어는 대기) |
| Android 13+ | 설정 > 앱 > 이룸 > 언어에 `한국어`·`English` 두 개만 뜬다. 고른 언어로 앱 화면이 바뀐다. 홈 화면 이름은 `이룸` 그대로다 |
| Android 12 이하 | 앱 설정에 언어 항목이 없다. 기기 언어를 영어로 바꾸면 앱 화면이 영어다 |

확인한 기기·OS 버전과 결과를 #527 에 남긴다.
