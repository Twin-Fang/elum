# 이야기 글 공유 페이지 개편: 앱 자동 열기 + 앱 소개 화면 (#1041)

> 2026-10-30 · 이슈 https://github.com/Twin-Fang/elum/issues/1041 · 이전 설계 [2026-10-22-talk-post-share-link-design.md](./2026-10-22-talk-post-share-link-design.md)

## 문제

이야기 글 공유 링크(`/s/{글id}`, #966)를 카톡으로 받아 누르면 지금은 이렇게 돼요.

- **앱이 있어도 앱으로 안 가고** 웹 페이지가 떠요. 사람이 `이룸 앱에서 보기`를 한 번 더 눌러야 해요.
- 웹 페이지만 보고는 **이룸이 무슨 앱인지 알 수 없어요.** 글 카드 하나와 버튼 두 개뿐이라 앱을 받고 싶은 마음이 들지 않아요.
- 생김새가 밋밋해요. 로고·아이콘이 없고, 소개 사이트(twin-fang.github.io/elum)와 결이 달라요.

### 앱으로 안 가는 원인 (실측 2026-10-30)

| 플랫폼 | 상태 | 원인 |
|---|---|---|
| Android | App Links 검증 실패 | `/.well-known/assetlinks.json` 응답이 `[]`. 서버 설정 `talk.share.android-cert-sha256` 이 비어 있음 |
| iOS | Universal Links 꺼짐 | `apple-app-site-association` 은 정상 응답. 앱 `Runner.entitlements` 에 `applinks:` 가 없음 (Apple Developer 에서 Associated Domains 를 켜고 프로필을 다시 받아야 넣을 수 있어 #966 때 보류) |
| 카톡 안 | 위 둘을 고쳐도 부족 | 카톡 내장 브라우저는 App Links·Universal Links 로 앱을 열지 않는 경우가 많음 → 페이지가 직접 앱을 불러야 함 |

## 하려는 것

### 1. 앱이 있으면 저절로 그 글로 열기

| 어디서 눌렀나 | 동작 |
|---|---|
| Android (크롬·삼성 인터넷·카톡 등 전부) | 페이지가 뜨자마자 `intent://talk?post={id}#Intent;scheme=elum;package=kr.twinfang.elum;S.browser_fallback_url=…;end` 로 이동. 앱이 있으면 글 상세가 열리고, 없으면 같은 페이지(`?app=0`)로 돌아와 소개 화면을 보여 줌 |
| Android, App Links 검증 후 | 링크를 누르면 페이지 없이 바로 앱 (서명 키 SHA-256 을 설정에 넣으면 켜짐) |
| iOS 카톡·네이버·인스타 등 내장 브라우저 | 페이지가 뜨자마자 `elum://talk?post={id}` 한 번 시도. 앱이 없으면 그대로 소개 화면 |
| iOS Safari | 저절로 앱 주소를 부르지 않음 (앱이 없으면 Safari 가 "주소가 유효하지 않음" 창을 띄움). 대신 **Smart App Banner**(`apple-itunes-app` + `app-argument`) 로 화면 위에 `열기`/`받기` 가 뜸. Universal Links 가 켜지면 페이지 없이 바로 앱 |
| PC | 자동 시도 없음. 두 스토어 버튼 |

- 자동 시도는 **한 번만** 해요. `?app=0` 이 붙었거나 같은 탭에서 이미 시도했으면(sessionStorage) 다시 부르지 않아요.
- 버튼으로도 언제든 다시 열 수 있어요.

### 2. 앱이 없는 사람에게 보여 줄 소개 화면 다시 그리기

위에서 아래로:

1. **머리**: 이룸 로고 + 오른쪽 `앱 받기` 알약 버튼
2. **받은 글 카드**: 큰 썸네일, 분류, 제목, 한마디, `카드 5장`. 위에 "보호자가 이룸에서 만든 일과예요"
3. **주 버튼**
   - Android: `이룸 앱에서 보기` (앱 없으면 Play 스토어로 감 — intent fallback)
   - iOS: `App Store 에서 무료로 받기` + 아래 작은 글씨 버튼 `이미 앱이 있어요 · 앱에서 열기`
   - PC: 두 스토어 버튼
4. **이룸 소개**: "하루 일과를 행동 카드로 한 장씩" + 3단계(보호자가 적어요 → 카드로 나눠요 → 이룸이가 따라 해요). 소개 사이트 문구 그대로
5. **앱 화면 미리보기**: 소개 사이트의 실제 앱 캡처(휴대폰 틀) 1장
6. **아래**: 다시 스토어 버튼 + "앱을 받은 뒤 이 링크를 다시 누르면 글이 열려요" + 개인정보처리방침

모양:
- 소개 사이트와 같은 색(`#F7F2EF` 바탕, `#242634` 글자, `#FF8B26` 강조)과 Pretendard 글꼴
- 로고·캐릭터·앱 캡처는 **소개 사이트에 이미 올라간 파일을 주소로 불러 씀** (서버에 사본을 만들지 않음)
- 다크 모드 대응, 폭 360~480px 기준, PC 에서는 가운데 정렬 카드

### 3. 글을 못 찾을 때 (404)

같은 머리·소개·스토어 버튼에, 글 카드 자리에 "글을 찾을 수 없어요 · 글쓴이가 내렸거나 주소가 맞지 않아요 · `E-TALK-SHARE-GONE`"

## 검토한 안

| 안 | 고른 이유 / 버린 이유 |
|---|---|
| **A. 서버 페이지 안에서 기기별 자동 열기 + 소개 화면** (고름) | 지금 구조 그대로. 카톡 내장 브라우저까지 다룰 수 있는 유일한 방법 |
| B. App Links·Universal Links 만 켜기 | 카톡 안에서 안 됨. 그래도 함께 켬 |
| C. 페이지에서 iOS Safari 도 앱 주소 자동 호출 | 앱 없는 사람에게 오류 창이 뜸 → 버림 |
| D. 앱이 없으면 곧바로 스토어로 보내기 | 무슨 앱인지 모른 채 스토어로 튕겨 나감 → 버림 |

## 하지 않는 것

- 글쓴이·댓글을 페이지에 싣지 않음 (앱 밖으로 나가는 정보 최소화, #966 그대로)
- 스토어 설치 후 그 글로 바로 이어 주기(지연 딥링크) — 외부 서비스가 필요해서 하지 않음. 안내 문구로 대신함
- 초대 링크 페이지(`docs/public-pages/link`) 개편은 이번 범위 밖

## 실패 경로

| 상황 | 화면 |
|---|---|
| 앱 자동 열기 실패·앱 없음 | 소개 화면이 그대로 남음 (빈 화면·무한 이동 없음, 자동 시도 1회) |
| 썸네일 없음 | 기본 미리보기 그림 (지금과 같음) |
| 소개 사이트 그림을 못 불러옴 | 그림 칸만 비고 글·버튼은 그대로 (그림 실패가 화면을 깨지 않게 높이 고정) |
| 글 없음·내려감 | 404 + `E-TALK-SHARE-GONE` |
| JavaScript 꺼짐 | 자동 열기만 안 되고 버튼은 그대로 동작 |

## 사람이 해야 하는 것

- [ ] **Play Console > 앱 무결성 > 앱 서명 키 인증서 SHA-256** 값 전달 → 서버 설정에 추가하면 Android 는 링크를 누르자마자 앱으로 감 (업로드 키 지문은 이번에 먼저 넣음)
- [ ] **Apple Developer > Identifiers > kr.twinfang.elum > Associated Domains 켜기 → 배포 프로필 다시 받기 → Secret `APPLE_PROVISIONING_PROFILE_BASE64` 교체** → 그다음 `Runner.entitlements` 에 `applinks:api.elum.chuseok22.com` 추가 (순서가 바뀌면 iOS 빌드가 서명 오류로 실패)
- [ ] 실기기 카톡에서 링크 눌러 보기 (앱 있음 / 없음, iOS / Android)

## 구현 위치

| 파일 | 역할 |
|---|---|
| `talk/application/dto/request/TalkShareVisitor` | User-Agent > 플랫폼 3갈래 + 내장 브라우저 여부 |
| `talk/application/dto/response/TalkShareAppLinks` | 앱 주소·Android 버튼 intent·자동 열기 주소 |
| `TalkSharePageController` | `?app=0` 받기, Safari 앱 배너 값 |
| `templates/share/talk-post.html` | 화면. 자동 열기는 `body[data-auto-open]` 1회 (sessionStorage) |
| `application.yml` `talk.share.android-cert-sha256` | 기본값 업로드 키 지문. Play 앱 서명 키는 받으면 추가 |
