# 네이티브와 스토어 언어 설정 설계 (#527)

> 상위 #521 · 계획 `docs/superpowers/plans/2026-10-02-i18n-6-native-store.md` · 2026-10-29

## 문제

- iOS 권한 문구는 ko·en 두 벌뿐이고 ja·zh·es 는 없다. 앱별 언어 목록(`CFBundleLocalizations`)을 명시하지 않았다.
- Android 앱 이름이 매니페스트에 한글로 박혀 있고, 앱별 언어 선언(`locales_config`)이 없어 Android 13+ 설정의 앱별 언어 목록에 이룸이 안 뜬다.
- 스토어 문구는 한국어 한 벌(`docs/store/store-listing.md`)이고 다른 언어 원본 자리가 없다. 한국어 설명에 용어 규칙과 다른 `휴대폰` 이 남아 있다.
- 심사 노트가 `The app is Korean-only.` 라고 말하지만 앱은 ko·en 을 연다(#521). 노트가 인용한 버튼 이름(`Apple로 계속하기`)도 실제 버튼(`Apple로 로그인`)과 다르다.

## 정한 것

앱별 언어 목록은 **연 언어만** 등록한다(이슈 본문 · 계획 D1). 지금 연 언어는 `openedAppLocales` 의 ko·en 이다. 이 범위는 바꾸지 않는다.

| 영역 | 하는 것 |
|---|---|
| iOS 연 언어 | `CFBundleLocalizations` = en·ko 명시. 이미 번들에 있는 두 lproj 와 같아 노출 범위는 그대로 |
| iOS 안 연 언어 | ja·zh-Hans·es `InfoPlist.strings` 번역을 `client/ios/staged_locales/` 에 둔다. Xcode 프로젝트에 넣지 않아 번들에 안 들어간다 |
| Android | 앱 이름을 `@string/app_name`(값 `이룸` 그대로)으로 옮기고, `locales_config.xml` = ko·en 과 `android:localeConfig` 선언 |
| 규칙 검사 | `client/tool/check_native_locales.dart`: 연 언어 목록(`app_locales.dart`)과 iOS lproj·pbxproj·`CFBundleLocalizations`·Android `locales_config` 가 같은지, 권한 키가 빠지지 않았는지, 대기 언어가 연 언어와 겹치지 않는지. Flutter CI 규칙 검사 단계에 더한다 |
| 스토어 문구 | `docs/store/locales/` 에 en·ja·zh·es 초안과 README(로케일 코드, 글자 수 한도, 업로드 경로, 여는 순서). **업로드 경로 밖**이다 |
| 한국어 원본 | `store-listing.md` 의 `휴대폰` → `기기` |
| 심사 노트 | `Korean-only` 문장을 실제 동작(기기 언어 따라 ko·en)으로 고치고, 인용한 버튼 이름을 영어 ARB 값 + 한국어 괄호로 바꾼다 |

## 검토한 안과 고른 이유

| 안 | 판단 |
|---|---|
| ja·zh·es lproj 를 Runner 에 넣고 pbxproj 에 등록 | 안 고름. iOS 는 번들의 lproj 로 지원 언어를 정해 설정 > 이룸 > 언어와 App Store 언어 표시에 바로 뜬다. 열지 않은 언어가 목록에 뜨면 고른 사람이 영어 화면을 본다 |
| lproj 를 Runner 에 두되 pbxproj 에만 안 넣음 | 안 고름. Xcode 가 폴더를 다시 읽거나 사람이 "Add Files" 하면 조용히 들어간다. 폴더를 아예 분리해야 실수로 번들되지 않는다 |
| **Runner 밖 `staged_locales/` 에 대기, 열 때 옮김** | 고름. 번역 결과는 남기고 노출은 막는다. 검사 스크립트가 연 언어와 대기 언어의 겹침을 막는다 |
| Android `values-ja`·`values-b+zh+Hans`·`values-es` 생성 | 이번엔 안 만듦. Android 가 언어별로 바꿀 문자열은 앱 이름 하나인데 앱 이름 현지 표기(계획 D2)가 정해지지 않아 세 폴더 모두 `이룸` 사본이 된다. 표기가 정해지면 그때 만든다 |
| 스토어 초안을 `client/ios/fastlane/metadata/<로케일>/` 에 둠 | 안 고름. iOS 배포(`store_prepare`·`store_submit`)의 `deliver` 가 `skip_metadata: false` 로 이 폴더를 통째로 올려, 다음 배포에서 검수 안 된 문구로 새 로컬라이제이션이 생긴다 |
| Fastfile 에 로케일별 업로드 배선(`StoreLocales`) 추가 | 이번엔 안 함. 올릴 언어가 아직 없고 fastlane 실제 실행으로 시험할 수 없다. 첫 스토어 언어를 열 때 그 PR 에서 한다(README 에 순서) |

## 하지 않는 것

- 앱 화면 언어 범위(ko·en) 변경, 앱 이름 표기 변경(모든 언어 `이룸` 유지 · D2 미정)
- 스토어 콘솔 작업(언어 추가, 스크린샷, 이미 올라간 설명 갱신), 실기기 확인 — 사람이 한다
- Fastfile·배포 워크플로 업로드 경로 변경, 배포
- 홍보 이미지·사이트 문구(`docs/store/promo/*`)의 `휴대폰` — 렌더한 이미지와 묶여 있어 따로 다룬다

## 실패 경로

| 상황 | 결과 |
|---|---|
| 누가 언어를 Runner 에만 넣고 연 언어 목록에 안 더함 | 검사 스크립트가 목록 불일치로 CI 실패 |
| 권한 키를 Info.plist 에 더하고 번역을 안 담 | 검사 스크립트가 빠진 키로 실패(연 언어·대기 언어 모두) |
| `locales_config.xml` 문법 오류 | 빌드 전에 XML 파싱으로 확인. 앱 빌드는 aapt 단계에서 실패해 배포로 못 나간다 |
| Android 12 이하 | OS 앱별 언어가 없다. `localeConfig` 는 무시되고 기기 언어를 따른다(알려진 한계, README 에 적음) |
| 스토어 초안이 업로드 경로에 들어감 | README 에 금지 명시. `docs/` 아래라 fastlane 이 읽지 않는다 |

## 검증

- `flutter analyze`, `dart run tool/check_native_locales.dart`, 기존 `check_*` 중 바뀐 범위
- `plutil -lint` (Info.plist, 모든 InfoPlist.strings), Android XML 파싱
- 빌드는 안 한다(네이티브 리소스만 바뀌고 문법은 위에서 확인)
