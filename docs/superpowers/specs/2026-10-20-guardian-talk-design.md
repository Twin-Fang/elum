# 보호자 이야기 칸 설계 (일과 나눔)

- 날짜: 2026-10-20
- 관련: #786 (이야기 칸 장기 과제), #777 (일과 분류 6개), #849 (보호자 닉네임)
- 상태: 초안 2 (2026-10-20 피드백 반영, 사용자 검토 전)
- 흐름 시안: `.superpowers/brainstorm/37721-1792504882/content/talk-flows-v2.html`
- 시안: 브레인스토밍 화면 시안 `talk-overview.html` (피드·상세·올리기·가져오기 4장). 디자이너 시안은 아직 없다.

## 1. 왜 만드는가

10/19 실증 회의에서 보호자 A가 요청한 것:

- 좋은 행동 카드 묶음(일과)과 쓰는 요령을 다른 보호자와 나누고 싶다.
- 발달장애는 스펙트럼이라 한 집 사례가 그대로 맞지는 않지만, 비슷한 목적끼리 모으면 통한다.
- 행동 지원 방법을 모르는 보호자도 남이 쓴 일과를 보면 따라 할 수 있다.

지금 하단 바의 `이야기` 칸(`/guardian/talk`)은 준비 중 화면이다. 이 칸을 **실제로 앱을 쓰는 보호자**가 쓸 수 있는 기능으로 연다. 시연용이 아니다. 베타지만 제대로 만든다.

**한 줄 정의**: 보호자가 자기 일과와 "이렇게 했어요" 한마디를 함께 올리고, 다른 보호자는 그것을 보고 "내 일과로" 가져간다.

## 2. 목표 · 하지 않는 것 · 실패로 보는 것

### 목표
1. 보호자가 일과(카드 그림 포함)와 짧은 글을 이야기에 올릴 수 있다.
2. 다른 보호자는 최신순 피드에서 그것을 보고, 카드 전체를 펼쳐 보고, 버튼 하나로 자기 이룸이의 **일과관리**로 가져갈 수 있다 (AI 호출 없음. 당연한 일이라 화면에 내세우지 않는다).
3. 도움돼요와 댓글로 반응할 수 있다.
4. 신고·차단·이용 규칙·관리자 확인을 갖춰 앱스토어 UGC 요건(App Review Guideline 1.2)을 만족한다.
5. 이룸이 실명·얼굴 사진이 의도치 않게 남에게 나가지 않는다.

### 하지 않는 것 (이번 범위 밖)
- 운영팀 소식·공지 칸 (공지는 이미 별도 기능이 있다)
- 일과 없이 글만 쓰는 자유 글, 질문 글
- 팔로우, 프로필 페이지, 쪽지
- "후기가 달리면 다시 위로 올리기" 같은 복잡한 정렬
- "N번째 해냈어요, 나눠 볼까요?" 제안
- 가져간 집 중 몇 집이 해냈는지 세기 (원본 연결은 남겨 두어 나중에 가능하게만 한다)
- 댓글의 답글(대댓글), 댓글 수정

### 실패로 보는 것 (동작해도 실패)
- 이룸이 실명이나 얼굴이 보호자 확인 없이 피드에 나간다.
- 가져온 일과가 보호자 확인 없이 이룸이 화면에 바로 뜬다 (서비스 원칙 3).
- 첫 화면이 비어 "죽은 서비스"처럼 보인다.
- 신고해도 아무 일이 일어나지 않는다.
- 남의 원본 일과를 고치거나 지우면 공유글이 깨진다(그림이 사라진다).

## 3. 정해진 것 (사용자와 합의)

| 항목 | 결정 |
|---|---|
| 올리는 단위 | 일과 1개 + "이렇게 했어요" 한마디(선택) + 분류 1개 |
| 분류 | 앱의 일과 분류 6개 그대로(`RoutineTemplateCategory`, 내용·개수 불변). **이름만 바꾼다**: 생활 습관 · 하루 순서 · 집안일 · 바깥 활동 · 공부 · 감정·관계. 같은 ARB 키라 예시 일과 시트 이름도 함께 바뀐다(분류 목록은 하나로 유지) |
| 분류 고르기 | 칸마다 그림 + 예시 일과 3개(하루 순서는 "여러 일을 차례로" 덧붙임). 일과 제목을 예시 일과 목록과 맞춰 가장 가까운 분류를 미리 골라 둔다(앱 안, AI 없음). 못 찾으면 비워 둔다. 보호자는 바꿀 수 있고 내 글 고치기에서도 바꿀 수 있다 |
| 피드 정렬 | 최신순. 인기는 피드 맨 위 가로 줄 "많이 가져갔어요"(이번 주)에만 |
| '꿀팁' 대신 쓰는 말 | **이렇게 했어요** |
| 입구 3곳 | ① 홈 끝낸 일과 카드 아래 "이야기에 공유해 보기" ② 일과 상세 시트 ⋯ 메뉴 ③ 이야기 칸 "+ 올리기" |
| 반응 | 도움돼요(1인 1회, 다시 누르면 취소) · 댓글 |
| 운영팀 소식 | 넣지 않는다 |
| 글쓴이 이름 | 보호자 닉네임 `Member.nickname` (#849, 자동 생성 "가파른블록-1269", 본인이 바꿀 수 있음). `profile_guardian.display_name`("엄마" 등 가족 안 호칭)은 쓰지 않는다 |

## 4. 2차로 정한 것 (2026-10-20 사용자 피드백 반영)

1. **사진 흐리게 = 사진마다 묻고 고르게**: 보호자가 직접 찍은 사진 카드가 있을 때만 묻는다. 미리 골라 둔 값은 없고, 사진마다 "흐리게 / 그대로"를 골라야 다음으로 간다. AI 그림·예시 그림·픽토그램은 묻지 않고 그대로 올린다. (사용자 결정)
2. **이룸이 이름 가리기**: 올릴 때 일과 제목·카드 제목·설명·한마디에서 이룸이 호칭(`Profile.nickname`)을 "이룸이"로 바꾼다. 바뀐 결과를 올리기 전에 미리보기로 보여 준다. (사용자: 그대로 유지)
3. **가져오기 = 일과관리로**: 임시저장은 찾아 들어가기 어렵다(사용자). 가져온 일과는 고른 이룸이의 **일과관리**에 `libraryOnly` 원본으로 들어간다. 일과관리 "복사하기"와 같은 방식이라 이룸이 화면에는 뜨지 않고, 보호자가 "보내기"를 눌러야 이룸이에게 간다(서비스 원칙 3 유지). (사용자 결정, 넣는 곳 표시는 6.4)
4. **신고 자동 숨김 없음**: 신고는 관리자 화면에 쌓이기만 하고, 운영팀이 보고 내린다. (사용자 결정)
5. **⋯ 메뉴**: 남의 글은 신고 · 이 보호자 글 숨기기(차단). 내 글은 고치기(한마디·분류만) · 내리기. (제 판단)
6. **이용 규칙 동의**: 처음 올리거나 처음 댓글 달 때 한 번 동의받는다. (사용자 확인)
7. **알림 = 푸시**: 내 글에 댓글이 달리거나 누가 가져가면 **푸시**로 알리고 알림 목록에도 남긴다. 글 하나당 한 줄로 묶는다. (사용자 결정)
8. **화면에 "AI 크레딧 안 써요"를 내세우지 않는다**: 가져오기에 크레딧이 안 드는 건 당연한 일이다. (사용자)

## 5. 지금 코드 상태 (2026-10-20 origin/develop 기준)

설계가 기대는 사실만 적는다. 경로 약어: `S/` = `server/src/main/java/com/chuseok22/elumserver/`, `C/` = `client/lib/`.

- **일과**: `Routine`(`S/routine/infrastructure/entity/Routine.java`)는 `profile`, `createdBy`, `title`, `status`, `language`(만들 때 고정), `sourceRoutineId`(문자열, 외래키 없음), `steps`를 가진다. `RoutineStep`은 `stepOrder`, `title`, `description`, `imagePath`(저장소 열쇠), `pictogramId`, `exampleImageId`, `speechPath`.
- **상태**: `RoutineStatus` = `PENDING_REVIEW`(앱의 임시저장) · `CONFIRMED` · `COMPLETED`. DRAFT 값은 따로 없다.
- **복사**: `RoutineRules.copyCardsOf(origin, createdBy)`는 **같은 프로필**에 `CONFIRMED`로만 복사한다. 그림은 같은 열쇠를 그대로 공유한다(새 파일 없음). AI·크레딧 호출 없음. 다른 프로필로 복사하는 경로는 없다.
- **카드 그림**: `RoutineImageStorage`(로컬 디스크). 열쇠 모양: AI `{batchId}/{stepOrder}.{ext}` · 추가 카드 AI `{stepId}/1.{ext}` · 보호자 사진 `{stepId}/{UUID}.jpg`. 사진/AI 구분 칼럼은 **없다**. 제공 `GET /api/routines/{routineId}/steps/{stepId}/image`는 그 프로필에 연결된 사람만 받는다.
- **이룸이 실명**: AI는 "이룸이" 자리표시로 만들지만 `RoutineAiPipeline.restoreNickname`이 저장 전에 실명으로 되돌린다. 저장된 일과에는 실명이 그대로 있다. `NicknamePlaceholder.mask(text, nickname, locale)`가 반대 방향 변환을 한다.
- **분류 6개**: 클라이언트에만 있다(`C/features/guardian/domain/routine_template.dart`의 `RoutineTemplateCategory { selfCare, dailyFlow, household, community, learning, feelings }`). 서버·`Routine`에는 분류 칸이 없다.
- **알림**: FCM 푸시(`FcmPushSender`, `PushDispatcher`)와 앱 안 알림 목록(`Notification` 엔티티, `groupKey`로 한 줄 묶기, `NotificationType` 5종, `/api/notifications`, `unread-summary`)이 모두 있다.
- **관리자**: 목록 프레임워크(`AdminListDefinition`, `AdminListPaging`, `admin-list` 프래그먼트)가 있다. 새 목록은 `XxxList.DEFINITION` + 컨트롤러 + 템플릿 + 사이드 메뉴 한 줄. 회원 정지(`MemberStatus.SUSPENDED`)가 있다.
- **약관 동의**: `ConsentKey` 5개 고정 + `Member`의 boolean 칼럼. 항목을 늘리면 앱·서버 계약이 같이 바뀐다.
- **하단 탭**: `GuardianTab.talk` → `Routes.guardianTalk` → `GuardianComingSoonScreen(tab: GuardianTab.talk)` (`C/core/router/routes_guardian.dart:75-79`).
- **에러 코드**: 서버 `ErrorCode` enum ↔ 클라 `ServerErrorCode` 1:1. 화면 코드는 `E-XXX-nnn` 형식.
- **Flyway**: 최신 V50. 운영은 `ddl-auto: validate`라 마이그레이션 필수.

## 6. 화면과 흐름

### 6.1 피드 (`/guardian/talk`)
- 위: 제목 "이야기" + "+ 올리기" 버튼.
- 분류 칩: 전체 + 6개. 가로 스크롤.
- "많이 가져갔어요 · 이번 주": 최근 7일 가져가기 수 상위 최대 10개, 가로 카드(그림 2×2 + 제목 + "N명 가져감"). 해당 기간 가져가기가 0건이면 줄 자체를 숨긴다. 분류 칩을 고르면 그 분류 안에서 센다.
- "새로 올라왔어요": 최신순 무한 스크롤(커서 기반, 20개씩). 카드: 닉네임 · 몇 분 전 · 분류 배지 · 제목 · 카드 그림 최대 4장 + "+N" · 이렇게 했어요 한 줄 · 도움돼요 N · 댓글 N · "내 일과로" 버튼.
- 내가 숨긴(차단한) 보호자 글, 숨김 처리된 글은 보이지 않는다.
- 빈 상태(0건): 루미 일러스트 + "아직 나눈 일과가 없어요" + "첫 일과를 나눠 보세요" 버튼(올리기).
- 하단 광고 배너 자리는 기존 보호자 탭과 같은 규칙.
- 당겨서 새로고침.

### 6.2 상세
- 닉네임 · 시간 · 분류 · 제목 · 카드 수.
- 이렇게 했어요 전문.
- 카드 전체를 순서대로(그림 + 제목 + 설명).
- 도움돼요 버튼 · 댓글 수.
- 댓글 목록(오래된 순) + 입력창. 내 댓글은 길게 눌러 지우기.
- 하단 고정 "내 일과로 가져오기".
- ⋯ 메뉴: 4절 5번.

### 6.3 올리기 (3단계)
1. **일과 고르기**: 공유 단위는 **일과관리 원본**이다(7.9). 목록은 일과관리 원본 중 예시 일과(`isExample`)·숨긴 원본(`libraryHidden`)·이야기에서 가져온 일과(`talk_post_id` 있음)를 뺀 것. 임시저장(`PENDING_REVIEW`)은 일과관리에 없으므로 자연히 빠진다. 홈·상세 입구에서 들어오면 이 단계를 건너뛴다.
2. **사진 고르기**: 보호자 사진 카드가 있을 때만 나온다. 사진마다 "흐리게 / 그대로"를 고른다. 기본값 없음, 모두 골라야 "다음"이 켜진다. 고르면 바로 흐린 모습으로 미리 보인다. 안내: "얼굴, 이름표, 집 주소가 보이면 흐리게 해 주세요. AI로 만든 그림은 그대로 올라가요." 
3. **이렇게 했어요 + 분류 + 미리보기**: 한마디(선택, 최대 300자) · 분류 1개(필수) · 이름이 "이룸이"로 바뀐 카드 미리보기. 처음이면 이용 규칙 동의 시트가 먼저 뜬다.
- "올리기" → 성공 시 내 글 상세로 이동 + "이야기에 올렸어요" 스낵바.

### 6.4 가져오기 (일과관리로)
- 바텀시트 "어느 일과관리에 넣을까요?" / "넣은 뒤 우리 집에 맞게 고치고, 준비되면 보내기를 눌러 주세요."
  - 이룸이 선택: 연결된 이룸이가 2명 이상일 때만 보인다(현재 선택된 이룸이가 기본값).
  - 묶음 선택(선택): 기본 "묶음 없이". 묶음을 고르면 그 묶음 맨 뒤에 들어간다.
  - 버튼: 취소 · 일과관리에 넣기.
- 넣은 직후: 하단 스낵바 "{호칭} 일과관리에 넣었어요 · 보러 가기"(일과관리 칸으로 이동, 새 칸으로 스크롤). 상세 하단 버튼은 "✓ 일과관리에 넣었어요"로 바뀌고, 다시 누르면 한 번 더 넣을 수 있다.
- 일과관리 표시: 묶음 없이 넣으면 맨 앞 칸. 주황 테두리 + "새로" 배지(처음 열어 보면 사라짐, 로컬 저장) + 이름 아래 "이야기에서"(계속 남음).
- 가져온 일과 상세: 맨 위에 "📖 {닉네임}님이 이야기에 나눈 일과예요" + 원래 "이렇게 했어요" + 원래 글 링크(글이 내려갔으면 링크만 숨김). 버튼은 기존 일과관리 상세와 같다(고치기 · 보내기).
- 같은 글을 또 넣으면 새 칸을 또 만든다(막지 않는다). 가져가기 수는 보호자 1명당 1번만 센다.
- 제목은 글 제목 그대로("복사"를 붙이지 않음). 카드 글의 "이룸이"는 그대로 두고 보호자가 고치기에서 바꾼다. (제 판단)

### 6.5 입구
- **홈**: 오늘 끝낸(`COMPLETED`) 일과 카드 아래 텍스트 버튼 "이야기에 공유해 보기". 이미 올린 일과면 숨긴다. 닫기(×)를 누르면 그 일과에서는 다시 안 띄운다(로컬 저장).
- **일과 상세 시트 ⋯ 메뉴**: "이야기에 공유하기" 항목 추가. 임시저장 일과에는 숨긴다.
- **이야기 칸 + 올리기**.

## 7. 데이터와 서버

### 7.1 새 패키지 `S/talk/`
기존 계층 구조(`application/controller`, `application/service`, `infrastructure/entity`, `infrastructure/repository`, `core`)를 따른다.

### 7.2 표 (V51 이후 마이그레이션, 추가 전용)

| 표 | 주요 칼럼 | 비고 |
|---|---|---|
| `talk_post` | id, author_member_id, source_routine_id, title, note, category, language, step_count, status, helpful_count, comment_count, import_count, created_at, updated_at | status: `VISIBLE` · `HIDDEN_BY_ADMIN` · `DELETED`. 카운트는 비정규화(목록 성능) |
| `talk_post_step` | id, post_id, step_order, title, description, image_key, pictogram_id, example_image_id, is_blurred | 일과 카드의 **스냅샷**. 원본을 고치거나 지워도 그대로 |
| `talk_comment` | id, post_id, author_member_id, body, status, created_at | body 최대 300자. status: `VISIBLE` · `HIDDEN_BY_ADMIN` · `DELETED` |
| `talk_helpful` | post_id, member_id, created_at | (post_id, member_id) 유니크 |
| `talk_import` | id, post_id, member_id, profile_id, routine_id, created_at | 이번 주 인기·가져가기 수 계산. 나중에 "해낸 집" 세기의 연결 고리 |
| `talk_report` | id, target_type, target_id, reporter_member_id, reason, created_at, resolved_at | target_type: `POST` · `COMMENT`. (target_type, target_id, reporter) 유니크 |
| `talk_block` | blocker_member_id, blocked_member_id, created_at | 이 보호자 글 숨기기 |
| `member.talk_rules_agreed_at` | timestamp, null 허용 | 이용 규칙 동의 시각 |
| `routine.talk_post_id` | 문자열, null 허용 | 이야기에서 가져온 일과면 그 글 id |

- `category`는 서버 enum `TalkCategory { SELF_CARE, DAILY_FLOW, HOUSEHOLD, COMMUNITY, LEARNING, FEELINGS }`. 클라 `RoutineTemplateCategory`와 이름을 맞추고, 기존 `CrossStackContractTest` 방식으로 대조한다.
- 이용 규칙은 `ConsentKey`에 넣지 않는다. 법정 약관이 아니고, 넣으면 가입 동의 계약 전체가 바뀐다. 규칙 본문은 앱 ARB 문구로 둔다.

### 7.3 그림 저장 (공유 전용 사본)
- 새 저장소 `TalkImageStorage`(로컬 디스크, 기존 `RoutineImageStorage`와 같은 방식, 루트만 다름). 열쇠: `{postId}/{stepOrder}.{ext}`.
- 올릴 때 원본 카드 그림을 **복사**한다. 흐리게를 고른 사진 카드는 복사본에만 블러를 건다(서버에서 처리, 원본은 그대로). 블러 세기는 얼굴·글자를 알아볼 수 없을 정도.
- 사진 판정: 열쇠가 보호자 업로드 모양(`{stepId}/{UUID}.jpg`)인지로 본다. 판정 함수는 `RoutineImageStorage` 쪽에 하나만 두고(`isGuardianUploadedPhoto(imageKey)`), 열쇠 규칙이 바뀌면 같이 바뀌게 한다.
- 픽토그램·예시 그림은 공용 자원이므로 id만 복사한다.
- 제공: `GET /api/talk/posts/{postId}/steps/{stepOrder}/image` — 로그인한 보호자 누구나. 숨김·삭제된 글은 404.

### 7.4 가져오기
- 새 서비스 메서드가 `talk_post_step` 스냅샷으로 **대상 프로필**에 새 `Routine`을 만든다. `copyCardsOf`는 같은 프로필 전용이라 쓰지 않고, `RoutineLibraryService.newLibraryCopyOf`와 같은 규칙을 따르는 새 함수를 `RoutineRules` 옆에 둔다.
- 일과관리 원본으로 만든다: status `CONFIRMED`, `libraryOnly = true`(홈·이룸이 화면에 안 뜸), `sourceRoutineId = null`(일과관리 목록은 원본만 보여 준다), `libraryOrder` 맨 앞(묶음 없이) 또는 `groupId`·`groupOrder` 맨 뒤(묶음 선택). language는 글의 language, `createdBy`는 가져간 보호자.
- 어디서 왔는지: `Routine`에 새 칼럼 `talk_post_id`(문자열, 외래키 없음, `sourceRoutineId`와 같은 방식). "이야기에서" 표시와 원래 글 링크가 쓴다.
- 보유 일과 한도는 보지 않는다. 일과관리 "복사하기"(`RoutineLibraryService.copy`)도 한도를 보지 않는 것과 같다. (제 판단)
- 그림: 공유 사본을 가져간 쪽 `RoutineImageStorage`로 **새 열쇠로 복사**한다(그 프로필 권한으로 보이게). 원본 글이 나중에 내려가도 가져간 일과는 멀쩡하다.
- 음성(`speechPath`)은 기존 `saveWithSpeech`로 새로 만든다.
- 권한: 대상 프로필에 `RoutineAction.CREATE`(또는 동등) 권한이 있어야 한다.
- `talk_import` 한 줄 저장, 처음 가져간 보호자면 `import_count` +1.

### 7.5 API (모두 보호자 로그인 필요)

| 메서드 | 경로 | 하는 일 |
|---|---|---|
| GET | `/api/talk/posts?category=&cursor=` | 최신순 피드 |
| GET | `/api/talk/posts/popular?category=` | 이번 주 많이 가져간 글 |
| GET | `/api/talk/posts/{id}` | 상세 (카드·내 도움돼요 여부 포함) |
| POST | `/api/talk/posts/preview` | 고른 일과 → 이름 가린 미리보기 + 사진 카드 여부 (저장 안 함) |
| POST | `/api/talk/posts` | 올리기 (routineId, note, category, blurredStepIds: 흐리게 고른 사진 카드 id 목록) |
| PATCH | `/api/talk/posts/{id}` | 한마디·분류 고치기 (본인) |
| DELETE | `/api/talk/posts/{id}` | 내리기 (본인, soft delete) |
| PUT / DELETE | `/api/talk/posts/{id}/helpful` | 도움돼요 / 취소 |
| GET / POST | `/api/talk/posts/{id}/comments` | 댓글 목록 / 쓰기 |
| DELETE | `/api/talk/comments/{id}` | 댓글 지우기 (본인) |
| POST | `/api/talk/posts/{id}/import` | 일과관리에 넣기 (profileId, groupId 선택) → 새 routineId |
| POST | `/api/talk/reports` | 신고 (targetType, targetId, reason) |
| PUT / DELETE | `/api/talk/blocks/{memberId}` | 이 보호자 글 숨기기 / 풀기 |
| POST | `/api/member/talk-rules-agreement` | 이용 규칙 동의 |

- 응답의 글쓴이는 `authorNickname`과 `isMine`만 싣는다. memberId·아이디·이메일은 싣지 않는다. 차단 API용으로는 서버가 발급하는 불투명 `authorKey`를 쓴다.
- 이용 규칙 미동의 상태에서 올리기·댓글은 `TALK_RULES_NOT_AGREED`(403).

### 7.6 이름 가리기 규칙
- 올리기·미리보기 모두 같은 함수: 일과 `title`, 카드 `title`·`description`, 한마디 `note`에 `NicknamePlaceholder.mask(text, profile.nickname, routine.language)`.
- 미리보기에서 보호자가 결과를 확인한다. 가리기에 실패하면(예외) 원문을 쓰지 않고 올리기를 거절한다(`TALK_NICKNAME_MASK_FAILED`). 실명 노출보다 실패가 낫다.
- 한마디에 다른 사람 실명·연락처를 쓰지 말라는 안내를 입력창 아래에 둔다(자동 탐지는 하지 않는다, 서비스 원칙 2).

### 7.7 신고·숨김·관리자
- 신고 사유: 개인정보 노출 · 부적절한 내용 · 광고 · 기타.
- 자동 숨김 없음. 신고는 `talk_report`에 쌓이고 관리자가 보고 `HIDDEN_BY_ADMIN`으로 내리거나 신고를 닫는다. 같은 사람이 같은 대상을 두 번 신고할 수 없다.
- 미처리 신고 수를 관리자 사이드 메뉴 "이야기"에 표시한다.
- **신고 메일 (사용자 결정)**: 신고가 들어오면 운영자 메일로 바로 알린다(대상 글·댓글 요약, 사유, 관리자 화면 링크. 신고자 계정 정보는 넣지 않는다). 운영자가 제때 처리한다. 서버에 메일 발송 기능이 아직 없어 새로 둔다(`spring-boot-starter-mail` + SMTP, 받는 주소·SMTP 계정은 환경 변수, 값은 커밋하지 않음). 메일 발송 실패가 신고 저장을 막지 않는다(커밋 뒤 비동기, 실패는 로그).
- 신고 처리 방식(메일·운영팀 확인)은 화면·이용 규칙에 내세우지 않는다. 사용자에게는 "신고했어요"만 보인다. (사용자 결정)
- 관리자 `/admin/talk`: 글 목록(상태·신고 수 필터), 신고 목록, 글 상세(카드 그림 포함), 숨김·복원·삭제, 글쓴이 정지는 기존 회원 화면으로 링크. 사이드 메뉴에 "이야기" 추가.
- 회원 탈퇴 시: 그 회원의 글·댓글·도움돼요·차단 기록을 지운다(그림 파일 포함). 가져간 사람의 일과 사본은 남는다.
- 정지(`SUSPENDED`) 회원의 글·댓글은 피드에서 숨긴다.

### 7.8 알림
- `NotificationType`에 `TALK_POST_COMMENTED`, `TALK_POST_IMPORTED` 추가. `groupKey`는 글 id 단위 → "'처음 타는 버스'에 댓글이 3개 달렸어요" 한 줄.
- **푸시로 보낸다**(기존 `PushDispatcher`·FCM). 알림 목록에도 같은 줄이 남는다.
- 내 행동(내 글에 내가 댓글)은 알리지 않는다.
- 알림 설정에 항목 2개 추가: "이야기: 내 글에 댓글이 달렸을 때" · "이야기: 내 글을 가져갔을 때". 기본 켜짐.
- 이야기 알림은 특정 이룸이 소속이 아니다. `Notification.profileId`가 null을 허용하는지 확인하고, 안 되면 만드는 사람이 정한다.
- 알림을 누르면 해당 글 상세로.

### 7.9 그 밖의 규칙 (검토 뒤 정함, 제 판단)
- **공유 기준 id**: `talk_post.source_routine_id`는 일과관리 원본 id다. 홈 "끝낸 일과"(오늘 일과 복사본)에서 올리면 `sourceRoutineId`를 따라 원본으로 바꿔 쓴다. 원본 하나당 `VISIBLE` 글은 하나만 둔다(이미 올렸으면 입구 대신 "내 글 보기").
- **재공유 금지**: 이야기에서 가져온 일과는 올릴 수 없다. 남의 글이 새 글로 복제되는 것을 막는다.
- **피드 언어**: 피드·인기 줄은 보는 사람의 화면 언어와 같은 language 글만 보여 준다.
- **금칙어 거르기**: 한마디·댓글·제목에 `NicknamePolicy`의 욕설 목록(5개 언어)을 재사용해 걸리면 올리기를 거절한다(`TALK_TEXT_NOT_ALLOWED`). 앱스토어 1.2의 "올릴 때 거르는 수단".
- **댓글**: 댓글에는 이름 가리기를 하지 않는다(쓰는 사람이 보는 그대로 나간다). 남의 댓글 ⋯ 메뉴에 신고 · 이 보호자 글 숨기기, 내 댓글 ⋯ 메뉴에 지우기.
- **관리자 그림**: 관리자 전용 경로 `/admin/talk/posts/{id}/steps/{stepOrder}/image`(숨김·삭제 글도 보임, `no-store`).
- **알림 설정**: `NotificationSetting`에 칼럼 2개 추가(기본 켜짐). 이전 앱 버전이 새 필드를 몰라도 깨지지 않게 응답에 추가만 한다. 이야기 알림이 프로필 단위 목록 필터에 걸려 사라지지 않는지 확인한다.
- **회원 탈퇴**: 그 회원의 글(그림 포함)·댓글·도움돼요·신고·차단·`talk_import` 행을 지우고, 남의 글 카운트를 다시 센다. 가져간 사람의 일과 사본과 `talk_post_id`는 남긴다(글이 없으면 링크만 숨김).

## 8. 클라이언트

- `C/features/talk/` 새 기능 폴더 (presentation · application · data · domain), 디자인 토큰·공통 컴포넌트만 사용.
- `routes_guardian.dart`의 talk 브랜치를 `TalkFeedScreen`으로 교체. 상세·올리기는 그 아래 하위 경로.
- `GuardianComingSoonScreen`은 다른 칸이 쓰지 않으면 지운다.
- 카드 그림은 기존 카드 그림 위젯을 재사용하고 이미지 URL만 talk 경로로.
- 일과 상세 시트 ⋯ 메뉴, 홈 끝낸 일과 카드에 입구 추가.
- 문구는 ARB 5개 언어(ko 먼저, 나머지는 번역 단계). 용어 규칙: "아이" 금지(이룸이), 해요체, "승인" 대신 "임시저장".
- 일과 언어: 카드 글을 그리는 위젯과 음성은 글의 language를 넘긴다.

## 9. 실패 경로

| 상황 | 동작 | 코드 |
|---|---|---|
| 피드 불러오기 실패 | 재시도 버튼 + 에러 코드, 이전에 받은 목록이 있으면 유지 | `E-TALK-001` |
| 그림 하나 실패 | 그 칸만 픽토그램 대체 그림 | — |
| 올리기 실패 | 입력(한마디·분류·흐리게 선택) 유지, 다시 시도 | `E-TALK-010` + 서버 코드 |
| 이름 가리기 실패 | 올리기 거절, "잠시 뒤 다시 해 주세요" | `TALK_NICKNAME_MASK_FAILED` |
| 일과관리에 넣기 실패 | 시트 유지 + 다시 시도, 부분 생성 없음(트랜잭션) | `E-TALK-020` |
| 가져오기 중 그림 복사 일부 실패 | 그 카드는 그림 없이 만들고 계속(픽토그램 대체) | — |
| 글이 내려갔거나 숨김 | 상세 진입 시 "내려간 글이에요" 빈 상태 | `TALK_POST_NOT_FOUND` |
| 댓글 쓰기 실패 | 입력 유지 | `E-TALK-030` |
| 이용 규칙 미동의 | 동의 시트 띄움 | `TALK_RULES_NOT_AGREED` |
| 연결된 이룸이 0명 | 가져오기 버튼 대신 "이룸이를 먼저 연결해 주세요" | — |

## 10. 테스트 (결함 하나씩 겨눈다)

| 테스트 | 막는 결함 |
|---|---|
| 서버: 올리기 시 실명이 "이룸이"로 바뀐다 (제목·카드·한마디) | 이룸이 실명 노출 |
| 서버: 가리기 예외 시 올리기가 거절된다 | 실패 시 원문 노출 |
| 서버: 흐리게 선택 시 사진 카드 사본만 블러, 원본 파일 불변 | 원본 훼손·사진 노출 |
| 서버: 가져오기 결과가 `libraryOnly` 원본이고 오늘 일과·이룸이 화면에 없다, 크레딧이 줄지 않는다 | 확인 없이 이룸이에게 감·과금 |
| 서버: 흐리게 고른 사진만 블러, 고르지 않은 사진은 원본 그대로 | 선택 무시 |
| 서버: 원본 일과 삭제 후에도 글 그림이 나온다 | 공유글 깨짐 |
| 서버: 같은 사람이 같은 대상을 두 번 신고하면 거절 | 신고 중복 |
| 서버: 차단한 보호자 글·댓글이 피드에서 빠진다 | 차단 무효 |
| 서버: 응답에 memberId·아이디·이메일이 없다 | 계정 정보 노출 |
| 서버: `TalkCategory` ↔ 클라 enum 이름 일치 (계약 테스트) | 분류 어긋남 |
| 클라: 피드 실패 → 에러 코드 + 재시도, 0건 → 빈 상태 | 빈 화면·무한 로딩 |
| 실기기: 올리기 → 다른 계정 일과관리에 넣기 → "새로" 칸 확인 → 보내기 → 원작자 푸시 수신 | 전 흐름 |

## 11. 만드는 사람에게 맡기는 것
- 블러 알고리즘·세기 구체값, 썸네일 크기.
- 커서 페이지 형식, 인기 계산을 쿼리로 할지 캐시로 할지.
- 화면 세부 간격·애니메이션 (디자이너 시안이 오면 시안 우선).
- 표·칼럼 세부 이름 (위 표는 의도를 보여 주는 수준).

## 12. 남은 일 / 위험
- **화면 문구 한 장씩 확인 (사용자 요청)**: 전체 틀은 확정. 문구는 화면마다 사용자와 하나씩 확인한 뒤 ARB에 넣는다.
- **디자이너 시안 없음**: 브레인스토밍 목업으로 먼저 만들고, 디자인 요청(`/pro-design-brief`)을 따로 낸다.
- **앱스토어 심사**: 신고·차단·이용 규칙·관리자 조치가 하나라도 빠지면 거절 사유. 심사 메모(`client/ios/fastlane/review_notes.txt`)에 이야기 칸 설명과 신고 경로를 적는다.
- **개인정보처리방침**: 보호자가 올린 글·그림을 다른 보호자에게 공개하는 처리가 생긴다. 방침 문구 갱신 필요 여부를 법적 문구 절차로 확인한다(임의 수정 금지).
- 범위가 크므로 계획 단계에서 단계를 나눈다(예: ① 서버 모델·올리기·피드·상세 ② 가져오기 ③ 반응·댓글·알림 ④ 신고·차단·관리자). 단, ④가 빠진 상태로 운영 배포하지 않는다.
