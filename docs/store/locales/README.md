# 언어별 스토어 문구와 네이티브 언어 등록

> 이슈 [#527](https://github.com/Twin-Fang/elum/issues/527) · 상위 #521 · 설계 `docs/superpowers/specs/2026-10-29-native-store-locales-design.md`
> 한국어 원본은 [`../store-listing.md`](../store-listing.md). 번역 용어는 [`docs/i18n/glossary.md`](../../i18n/glossary.md).

## 지금 상태 (2026-10-29)

| 언어 | 앱 화면 | OS 앱별 언어 목록 | iOS 권한 문구 | 스토어 문구 |
|---|---|---|---|---|
| ko | 열림 | 등록 | `ios/Runner/ko.lproj` | 콘솔에 있음 (`store-listing.md`) |
| en | 열림 | 등록 | `ios/Runner/en.lproj` | **초안** [`en.md`](./en.md) — 콘솔에 없음 |
| ja | 닫힘 | 안 함 | 대기 `ios/staged_locales/ja.lproj` | **초안** [`ja.md`](./ja.md) |
| zh (간체) | 닫힘 | 안 함 | 대기 `ios/staged_locales/zh-Hans.lproj` | **초안** [`zh.md`](./zh.md) |
| es | 닫힘 | 안 함 | 대기 `ios/staged_locales/es.lproj` | **초안** [`es.md`](./es.md) |

- **초안은 사람 검수 전이다.** 이 폴더는 어떤 배포도 읽지 않는다. 검수한 뒤 콘솔에 넣는다.
- 검수 때 함께 볼 것: 한국어 원본 끝 문장 "앱 설정 화면의 **문의하기**에서 주소를 확인" 의 `문의하기` 는 지금 앱 설정에 없다(가장 가까운 항목은 `의견 보내기`). 초안은 원본을 그대로 옮겼다. 원본을 고치면 초안도 함께 고친다.
- 앱 이름은 모든 언어에서 `이룸` 이다. 현지 표기(영문 `elum`/`ELUM`, 일본어 가타카나 등)는 정하지 않았다(계획 D2). 정하면 iOS `InfoPlist.strings` 의 `CFBundleDisplayName` 과 Android `values-<언어>/strings.xml` 의 `app_name` 에 넣는다.

## 업로드 경로 — 초안을 넣지 않는 곳 ⚠️

| 파일 | 누가 올리나 | 결과 |
|---|---|---|
| `client/ios/fastlane/metadata/<로케일>/*.txt` | iOS 배포 `store_prepare`·`store_submit` 의 `deliver` (`skip_metadata: false`) | 폴더가 있는 언어는 **그대로 올라가고 새 로컬라이제이션이 생긴다**. 지금은 배포 때 `ko/release_notes.txt` 만 만들어 쓴다(`DELIVER_LOCALES` 기본 `ko`) |
| `client/ios/fastlane/review_notes.txt` | 같은 `deliver` | 심사 노트(Notes)를 매번 덮어쓴다. 레포가 원본 |
| `client/android/fastlane/metadata/android/<로케일>/changelogs/` | Play 배포 `upload_to_play_store` (`skip_upload_changelogs: false`) | 출시 노트가 올라간다. 지금은 워크플로가 `ko-KR` 만 만든다 |
| Play 이름·설명 | 없음 (`skip_upload_metadata: true`) | Play Console 에서 손으로 넣는다 |

검수 전 문구를 위 경로에 두면 다음 배포에서 그대로 스토어에 나간다. 이 폴더(`docs/store/locales/`)에만 둔다.

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
5. 스토어: 이 폴더의 초안을 검수한 뒤 App Store Connect·Play Console 에 그 언어를 추가하고 넣는다(스크린샷 포함). 배포로 자동 업로드하려면 그 언어 폴더를 업로드 경로에 만들고 `DELIVER_LOCALES` 와 Android 출시 노트 폴더를 그 PR 에서 함께 고친다.
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
