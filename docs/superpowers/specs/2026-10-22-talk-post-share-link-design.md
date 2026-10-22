# 이야기 글 공유 링크 설계 (2026-10-22)

## 문제

이야기 글을 앱 밖(카카오톡·문자)으로 보낼 방법이 없다. 좋은 일과를 다른 보호자에게 알리려면
화면을 캡처해 보내야 하고, 받은 사람은 앱이 있어도 그 글로 바로 갈 수 없다.

## 목표

- 이야기 글 상세에 `공유하기` 버튼 → OS 공유 시트로 문구 + 링크를 보낸다
- 카카오톡·문자에서 **썸네일 미리보기 카드**(제목·설명·첫 카드 그림)가 뜬다
- 링크를 열면
  - 앱이 있으면 → 앱의 그 글 상세로 간다
  - 앱이 없으면 → 웹 미리보기 + 스토어 설치 버튼 (iOS·Android 기기에 맞춰)
- iOS·Android 둘 다 동작한다

## 일반 앱과 견준 위치

인스타그램(`instagram.com/p/…`)·당근 웹 링크와 같은 구조다: 자기 도메인 링크 하나 > OG 미리보기 > Universal/App Links > 웹 폴백 + 스토어.
대기업이 더 하는 것 중 이번에 뺀 것: 설치 후 첫 실행 이어 주기(Airbridge·AppsFlyer 등 유료), 공유 전용 짧은 도메인, 클릭 통계.
도메인은 서버 설정값(`talk.share.public-base-url`) 하나라 나중에 바꿀 수 있다 (앱 매니페스트 호스트·entitlements 도 함께).

## 하지 않는 것

- Firebase Dynamic Links (2025-08 종료) · Branch 같은 외부 링크 서비스
- 설치 후 첫 실행에 그 글로 이어 주기(deferred deep link) — 웹 페이지가 "앱 설치 후 링크를 다시 눌러 주세요"로 안내
- 웹에서 글 전체(모든 카드·댓글)를 보여 주기 — 첫 카드 그림과 제목·한마디만
- 카카오 SDK 전용 공유 버튼 — OS 공유 시트에 카카오톡이 이미 있다
- 공유 페이지 다국어 — 한국어만 (서비스 언어가 한국어 위주, 필요해지면 따로)

## 검토한 안

| 안 | 판단 |
|---|---|
| github.io 정적 페이지 (초대 링크 방식) | ❌ 글마다 다른 `og:image`·`og:title` 을 못 만든다. 카톡 썸네일이 전부 같은 그림이 된다 |
| Firebase Dynamic Links | ❌ 서비스 종료 |
| **운영 서버(`api.elum.chuseok22.com`)가 공유 페이지를 그린다** | ✅ 글마다 OG 태그·썸네일을 만들 수 있고, 앱 연결 검증 파일도 같은 도메인에 둔다. 리버스 프록시가 `/s/`·`/.well-known/` 을 이미 Spring 까지 보낸다 (2026-10-22 실측: 둘 다 Spring 404 JSON) |

## 링크 모양

| 종류 | 모양 | 쓰임 |
|---|---|---|
| 웹 링크 | `https://api.elum.chuseok22.com/s/{postId}` | 공유 시트로 보냄. 카톡 미리보기·Universal/App Links 대상 |
| 앱 주소 | `elum://talk?post={postId}` | 웹 페이지의 `이룸 앱에서 보기` 버튼 |

- `postId` 는 UUID. 서버·앱 모두 UUID 모양이 아니면 조회하지 않는다
- 웹 링크 기준 주소: 앱은 `AppConfig.apiBaseUrl`, 서버는 요청 호스트가 아니라 설정값(`talk.share.public-base-url`, 기본 운영 주소)으로 `og:url` 을 만든다

## 서버

### 공유 페이지 `GET /s/{postId}` (인증 없음, `/api/**` 밖)

Thymeleaf `templates/share/talk-post.html`.

| 상태 | 화면 | OG |
|---|---|---|
| 볼 수 있는 글 | 분류 · 제목 · 한마디(120자) · 카드 수 · 첫 카드 그림 · `이룸 앱에서 보기` · `앱 받기` | `og:title`=제목, `og:description`=한마디 또는 "카드 N장 일과", `og:image`=`/s/{postId}/thumbnail` |
| 없음·내려감·정지 회원 글·모양이 틀린 id | "글을 찾을 수 없어요" + `E-TALK-SHARE-GONE` + `앱 받기` (HTTP 404) | 일반 소개 문구 + 기본 이미지 |

- 볼 수 있는 글 = `VISIBLE` 이고 글쓴이가 정지 회원이 아님 (차단은 보는 사람 기준이라 웹에선 적용 안 함)
- 글쓴이 닉네임·댓글은 싣지 않는다 (앱 밖으로 나가는 정보 최소화). 제목·한마디·카드 글은 올릴 때 이미 이룸이 호칭이 가려져 있고, 사진은 올린 사람이 고른 대로 흐려져 저장돼 있다
- `noindex, nofollow` — 검색에 잡히지 않게. 카카오 스크래퍼는 meta robots 와 무관하게 OG 를 읽는다
- `앱 받기`: UA 로 Android → Play, iOS → App Store, 그 밖 → 둘 다

### 썸네일 `GET /s/{postId}/thumbnail` (인증 없음)

- 볼 수 있는 글의 **그림이 있는 첫 카드** 그림을 그대로 내보낸다 (저장된 사본 = 흐림 반영본)
- 그림 카드가 없거나(픽토그램·예시 그림만) 글을 볼 수 없으면 → 기본 OG 이미지(`https://twin-fang.github.io/elum/assets/og.png`)로 302
- `Cache-Control: public, max-age=3600`

### 앱 연결 검증 파일

| 경로 | 내용 |
|---|---|
| `/.well-known/apple-app-site-association` | `applinks.details[0].appIDs=["CUK22HY6YC.kr.twinfang.elum"]`, `components=[{"/":"/s/*"}]`, `application/json` |
| `/.well-known/assetlinks.json` | `kr.twinfang.elum` + 인증서 SHA-256 목록 (설정값 `talk.share.android-cert-sha256`, 쉼표 구분, 비면 빈 배열) |

## 앱

### 보내기

- 상세 화면 `도움이 됐어요` 줄 오른쪽 끝에 `공유하기` (아이콘 + 글자)
- 문구(ARB `talkShareMessage`): `{제목}\n이룸 이야기에서 같이 봐요\n{링크}`
- 공유 시트는 기존 `shareWithSystemSheet`(share_plus) 재사용, 아이패드 팝오버 기준 사각형 전달
- 실패하면 `showFailure` (에러 코드 `TalkScreenCodes.shareLink` = `E-TALK-070`, `E-TALK-010` 은 올리기가 이미 씀)

### 받기

- `TalkPostLink.parse`: `elum://talk?post=…` · `https://{apiHost}/s/{id}` · 플랫폼이 호스트를 뗀 `/s/{id}`
- `TalkPostLinkIntake`: 우편함에 두었다가 **보호자 세션 + 보호자 홈·이야기 칸·이야기 상세**일 때 상세를 push
  - 로그인 전·온보딩 중 → 맡겨 둔다 (10분 안에 그 자리에 닿으면 연다)
  - 일과 만들기 등 다른 화면 → 하던 일을 끊지 않고 홈·이야기에 돌아오면 연다
  - 이룸이 기기 → 열지 않고 토스트 "보호자 화면에서 볼 수 있어요"
- 켜져 있을 때는 `InviteLinkHost`(라우터보다 먼저 받음), 꺼져 있다 열릴 때는 `createRouter` 리다이렉트가 받는다 — 초대·연결 암호 링크와 같은 길
- 글이 내려갔으면 상세 화면의 기존 "내려간 글" 상태가 처리한다

### 플랫폼 설정

| 플랫폼 | 이번에 | 사용자 작업 후 |
|---|---|---|
| Android | `elum://talk` 호스트 추가 + `https://api.elum.chuseok22.com/s/` `autoVerify` 인텐트 필터 | Play Console 앱 서명 키 SHA-256 → 서버 설정값. 그 전엔 링크가 브라우저(웹 페이지)로 열린다 |
| iOS | 변경 없음 (`elum` 스킴은 이미 등록) | Apple Developer 에서 App ID 에 Associated Domains 켜기 → 프로필 재발급·Secret 교체 → `Runner.entitlements` 에 `applinks:api.elum.chuseok22.com` 추가. **프로필보다 먼저 entitlements 를 넣으면 iOS 빌드가 서명 오류로 실패**해 이번엔 넣지 않는다 |

검증 파일이 맞기 전에도 공유는 동작한다: 링크 → 웹 페이지 → `이룸 앱에서 보기`(앱 주소) → 앱.

## 실패 경로

| 상황 | 동작 |
|---|---|
| 공유 시트 실패 | `showFailure` + 에러 코드 |
| 웹: 글 없음·내려감·정지·잘못된 id | 안내 + `E-TALK-SHARE-GONE` + 앱 받기, 404 |
| 웹: 그림 읽기 실패 | 기본 이미지로 302 (썸네일이 깨진 카드로 안 뜸) |
| 앱: 잘못된 링크 모양 | 무시 (라우터 오류 화면 안 뜸) |
| 앱: 링크로 열었는데 글이 내려감 | 상세 화면 "내려간 글" 상태 |
| 앱: 이룸이 기기 | 토스트 안내, 이동 없음 |
| 카톡 미리보기 캐시 | 글을 고쳐도 카톡이 예전 미리보기를 한동안 보여 줄 수 있다 (카카오 캐시) — 허용 |

## 테스트

- 서버 `TalkSharePageServiceTest` — 결함: 내려간 글·정지 회원 글이 공개 웹에 노출됨. 볼 수 없는 글은 빈 결과, 썸네일은 그림 있는 첫 카드
- 앱: `flutter analyze` · `tool/check_*`, 시뮬레이터 실측

## 남는 일 (사용자)

1. Apple Developer: Associated Domains 켜기 + 프로필 재발급 → 알려 주면 entitlements 추가
2. Play Console: 앱 서명 키 SHA-256 → 서버 설정값(`TALK_SHARE_ANDROID_CERT_SHA256`)
