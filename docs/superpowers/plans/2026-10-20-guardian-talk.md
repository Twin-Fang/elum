# 보호자 이야기 칸 (일과 나눔) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 보호자 하단 바 `이야기` 칸을 연다. 보호자가 일과관리 원본을 "이렇게 했어요"와 함께 올리고, 다른 보호자가 피드에서 보고 자기 이룸이 일과관리로 가져간다. 도움돼요 · 댓글 · 푸시 · 신고(메일) · 차단 · 관리자 화면까지 포함한다.

**Architecture:** 서버는 새 도메인 `talk`(글 스냅샷 · 그림 사본 · 반응 · 신고)를 두고, 일과 읽기·만들기는 `routine` 도메인의 공개 서비스 메서드 2개(스냅샷 뜨기, 일과관리로 넣기)를 통해서만 한다(다른 도메인 repository import 금지 규칙). 앱은 `features/talk`를 새로 만들고 talk 탭 브랜치의 준비 중 화면을 교체한다. 알림은 기존 `Notification` + FCM 경로에 타입 2개를 더한다.

**Tech Stack:** Spring Boot 4.1 / Java 21 / JPA / Flyway / Mockito, Flutter 3 / Riverpod 3(수동 provider) / Dio / go_router.

**Spec:** `docs/superpowers/specs/2026-10-20-guardian-talk-design.md` (실행자는 spec과 이 계획을 함께 읽는다)

## Global Constraints

- 운영 배포는 Task 1~22 전부 끝난 뒤 한 번. 신고·차단·관리자(Phase 4) 없이 운영에 내보내지 않는다 (App Store 1.2).
- 화면 문구: "아이" 금지(이룸이), 해요체·능동형, "승인" 금지(임시저장), "AI 크레딧 안 써요" 문구 금지, 신고 처리 방식(메일·운영팀)은 화면·규칙에 쓰지 않는다. 사용자에게는 "신고했어요"만.
- 한글 문구는 `client/lib/l10n/app_ko.arb`에만(`"@key": {"description"}` 동반). `dart run tool/check_hangul_literals.dart lib` 0줄. 키 추가 뒤 `cd client && flutter gen-l10n` 산출물 커밋.
- 서버: Bean Validation 금지, 서비스에서 `CustomException(ErrorCode.X)`. 컨트롤러는 `ResponseEntity` + `XxxControllerDocs`. `@LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)`. 로그에 글 본문·댓글 원문 금지.
- 다른 도메인의 `infrastructure.repository` import 금지 (`ArchitectureRulesTest`). 필요한 건 그 도메인 서비스에 공개 메서드를 더한다.
- 마이그레이션은 V51 한 개, `IF NOT EXISTS`만. 기존 칼럼·행 변경 금지(추가 전용).
- 응답에 memberId·아이디·이메일 금지. 글쓴이는 `authorNickname` + `isMine`.
- 앱 화면: 토큰(`context.colors/typo/space`)·`showElumSheet`·`showElumDialog`·`ElumButton`·`ElumErrorView`·`showElumToast`만. 하드코딩 색·간격 금지. 시트는 `showModalBottomSheet` 직접 금지.
- 피드 크기: 기본 20, 최대 50. 한마디·댓글 최대 300자. 인기 줄 최대 10개, 최근 7일.
- 분류 enum 값(서버·앱 동일): `SELF_CARE, DAILY_FLOW, HOUSEHOLD, COMMUNITY, LEARNING, FEELINGS`. 표시 이름: 생활 습관 · 하루 순서 · 집안일 · 바깥 활동 · 공부 · 감정·관계.
- 테스트 실행은 아낀다(레포 CLAUDE.md): 태스크마다 그 태스크 테스트 클래스만 `./gradlew test --tests '*X*'`. 서버 전체 테스트·앱 전체 analyze는 Task 22에서 1회. 다른 세션이 무거운 작업 중이면 미룬다. 앱 단위 테스트는 없다(`client/test` 삭제됨) — 앱 검증은 `flutter analyze <바꾼 파일>` + 규칙 도구 + 시뮬레이터.
- 커밋은 `/pro-commit`(이슈 번호 자동), 내가 만든 경로만 스테이징. `git add -A` 금지.

## Review Focus

1. **이룸이 실명이 남는 경로** — 제목·카드 제목·카드 설명·한마디 4곳 모두 가려져야 한다. 호칭이 null/빈 문자열이면 원문 그대로 통과(가릴 게 없음)해야 하고 예외가 나면 안 된다 → Task 4 테스트 `create_withoutNickname_keepsTextAndSucceeds`.
2. **그림 없는 카드·픽토그램만 있는 카드** — 이미지 키가 null인 카드가 섞여도 올리기·가져오기가 실패하지 않는다 → Task 4 `create_stepWithoutImage_copiesPictogramOnly`, Task 7 `importToLibrary_stepWithoutImage_keepsPictogram`.
3. **글이 내려간 뒤의 접근** — 피드에서 받은 id로 상세·그림·댓글·가져오기를 부르면 404(`TALK_POST_NOT_FOUND`), 500이 아니다 → Task 5 `detail_deletedPost_throwsNotFound`, Task 7 `importToLibrary_deletedPost_throwsNotFound`.
4. **잘못된 커서·분류 값** — 이상한 cursor는 처음부터, 모르는 category 문자열은 400(`INVALID_INPUT_VALUE`) → Task 5 `feed_malformedCursor_returnsFirstPage`, `feed_unknownCategory_throwsInvalidInput`.
5. **연결된 이룸이가 없는 보호자 / 남의 이룸이로 가져오기** — profileId가 내 이룸이가 아니면 403(`PROFILE_ACCESS_DENIED`) → Task 7 `importToLibrary_otherProfile_throwsAccessDenied`. 앱은 이룸이 0명이면 버튼 대신 안내(Task 17).

---

## 파일 구조

```
server/src/main/java/com/chuseok22/elumserver/
  talk/
    core/            TalkCategory, TalkPostStatus, TalkCommentStatus, TalkReportTargetType, TalkReportReason,
                     TalkTextRules(길이·금칙어), TalkCursor
    infrastructure/
      entity/        TalkPost, TalkPostStep, TalkComment, TalkHelpful, TalkImport, TalkReport, TalkBlock
      repository/    각 엔티티 Repository
      storage/       TalkImageStorage, LocalFileTalkImageStorage
      image/         TalkImageBlurrer
      mail/          TalkReportMailer, SmtpTalkReportMailer, NoOpTalkReportMailer, TalkReportMailConfig
    application/
      dto/request/   TalkPostCreateRequest, TalkPostUpdateRequest, TalkPreviewRequest, TalkCommentRequest,
                     TalkImportRequest, TalkReportRequest, TalkBlockRequest
      dto/response/  TalkPostSummaryResponse, TalkPostDetailResponse, TalkFeedPageResponse, TalkPreviewResponse,
                     TalkCommentResponse, TalkCommentPageResponse, TalkImportResponse, TalkBlockResponse
      service/       TalkPostService(올리기·고치기·내리기), TalkFeedQueryService(피드·인기·상세·그림),
                     TalkReactionService(도움돼요·댓글), TalkImportService, TalkModerationService(신고·차단),
                     TalkAdminService, TalkCleanupService(탈퇴)
      controller/    TalkController(+Docs), TalkReactionController(+Docs), TalkModerationController(+Docs)
  routine/application/service/RoutineShareService.java     (새: 스냅샷 뜨기 · 일과관리로 넣기)
  routine/application/dto/RoutineShareSnapshot.java, RoutineImportDraft.java
  member/…  MemberService(이용 규칙 동의·닉네임 조회·정지 여부), NicknamePolicy.containsBlockedWord
  notification/… 타입 2개, 이벤트 2개, 설정 칼럼 2개
  admin/application/controller/AdminTalkController.java, admin/application/list/AdminTalkPostList.java, AdminTalkReportList.java
server/src/main/resources/db/migration/V51__create_talk_tables.sql
server/src/main/resources/templates/admin/{talk,talk-detail,talk-reports}.html

client/lib/features/talk/
  domain/        talk_post.dart(TalkPostSummary, TalkPostDetail, TalkPostStep), talk_comment.dart,
                 talk_category.dart(→ RoutineTemplateCategory 재사용, 아래 참고), talk_category_suggester.dart
  data/          talk_repository.dart, talk_image_repository.dart
  application/   talk_feed_controller.dart, talk_popular_provider.dart, talk_detail_controller.dart,
                 talk_comment_controller.dart, talk_share_controller.dart, talk_rules_provider.dart
  presentation/  talk_feed_screen.dart, talk_detail_screen.dart, talk_share_screen.dart,
                 widgets/(talk_post_card, talk_popular_row, talk_category_chips, talk_step_image,
                 talk_import_sheet, talk_rules_sheet, talk_report_sheet, talk_block_dialog,
                 talk_photo_blur_picker, talk_category_picker, talk_comment_list, talk_more_menu)
```

분류는 새 enum을 만들지 않는다. `features/guardian/domain/routine_template.dart`의 `RoutineTemplateCategory`에 서버 값을 붙여 그대로 쓴다(단일 원본).

---

## Phase 0 — 준비

### Task 0: 이슈 · 작업 공간

- [ ] **Step 1:** `/pro-github`로 이슈 생성. 제목 `⚙️[기능추가][클라][이야기] 보호자끼리 일과를 나누고 일과관리로 가져가는 이야기 칸`, 본문에 spec·plan 경로, 라벨 `작업중`. #786, #906 연결.
- [ ] **Step 2:** `git fetch origin && git log --oneline origin/develop -1`로 최신 확인 후 `/pro-init-worktree <브랜치명>` → worktree 안에서 `scripts/copy-worktree-local-files.sh`.
- [ ] **Step 3:** spec·plan 두 문서를 이 브랜치에 커밋 (`/pro-commit`).

---

## Phase 1 — 서버: 모델 · 올리기 · 피드 · 상세

### Task 1: 마이그레이션 · 엔티티 · enum · 분류 계약

**Files:**
- Create: `server/src/main/resources/db/migration/V51__create_talk_tables.sql`
- Create: `talk/core/{TalkCategory,TalkPostStatus,TalkCommentStatus,TalkReportTargetType,TalkReportReason}.java`
- Create: `talk/infrastructure/entity/*.java`, `talk/infrastructure/repository/*.java`
- Modify: `routine/infrastructure/entity/Routine.java` (+`talkPostId`), `member/infrastructure/entity/Member.java` (+`talkRulesAgreedAt`), `notification/infrastructure/entity/NotificationSetting.java` (+2)
- Modify: `client/lib/features/guardian/domain/routine_template.dart` (enum에 서버 값)
- Test: `server/src/test/java/com/chuseok22/elumserver/common/CrossStackContractTest.java`

**Interfaces — Produces:**
- `enum TalkCategory { SELF_CARE, DAILY_FLOW, HOUSEHOLD, COMMUNITY, LEARNING, FEELINGS; static TalkCategory parse(String raw) }` — 모르는 값·null은 `CustomException(INVALID_INPUT_VALUE)`.
- `enum TalkPostStatus { VISIBLE, HIDDEN_BY_ADMIN, DELETED }`, `enum TalkCommentStatus { VISIBLE, HIDDEN_BY_ADMIN, DELETED }`
- `enum TalkReportTargetType { POST, COMMENT }`, `enum TalkReportReason { PERSONAL_INFO, OFFENSIVE, ADVERTISING, OTHER }`
- 엔티티(모두 `BaseEntity` 상속, `@Id @GeneratedValue(strategy = UUID) String id`, 외래키 없는 문자열 id):
  - `TalkPost(authorMemberId, sourceRoutineId, title, note, category, language(AppLocale), stepCount, status, helpfulCount, commentCount, importCount)`
  - `TalkPostStep(postId, stepOrder, title, description, imageKey, pictogramId, exampleImageId, isBlurred)`
  - `TalkComment(postId, authorMemberId, body, status)`
  - `TalkHelpful(postId, memberId)` 유니크 (post_id, member_id)
  - `TalkImport(postId, memberId, profileId, routineId)` 인덱스 (post_id, created_at)
  - `TalkReport(targetType, targetId, postId, reporterMemberId, reason, resolvedAt)` 유니크 (target_type, target_id, reporter_member_id)
  - `TalkBlock(blockerMemberId, blockedMemberId)` 유니크 (blocker, blocked)
- `Routine.talkPostId`(String, `talk_post_id`), `Member.talkRulesAgreedAt`(LocalDateTime), `NotificationSetting.talkCommentedEnabled`, `talkImportedEnabled` (`boolean not null default true`)
- 인덱스: `talk_post (status, language, created_at desc)`, `talk_post (status, language, category, created_at desc)`, `talk_post (author_member_id)`, `talk_post (source_routine_id)`, `talk_comment (post_id, created_at)`.
- 앱: `enum RoutineTemplateCategory { selfCare('SELF_CARE'), dailyFlow('DAILY_FLOW'), household('HOUSEHOLD'), community('COMMUNITY'), learning('LEARNING'), feelings('FEELINGS'); const RoutineTemplateCategory(this.serverValue); final String serverValue; static RoutineTemplateCategory? fromServer(String? raw) }`

- [ ] **Step 1: 실패하는 계약 테스트** — `CrossStackContractTest.sharedEnumsMatchClient`에 한 줄:
```java
assertSameValues("features/guardian/domain/routine_template.dart", TalkCategory.values(), Enum::name);
```
- [ ] **Step 2:** `./gradlew test --tests '*CrossStackContractTest*'` → FAIL (TalkCategory 없음 / 앱 enum에 값 없음)
- [ ] **Step 3:** enum·엔티티·repository·V51 작성, 앱 enum에 `serverValue` 추가. V51 형식은 `V47__create_notification_tables.sql`을 따르고 `MigrationRollbackContractTest`가 요구하는 주석·되돌리기 규칙을 먼저 읽는다. Repository 메서드는 이후 태스크가 필요할 때 더한다.
- [ ] **Step 4:** `./gradlew test --tests '*CrossStackContractTest*' --tests '*MigrationRollbackContractTest*'` → PASS, `./gradlew compileJava compileTestJava` 통과
- [ ] **Step 5:** `/pro-commit`

### Task 2: 에러 코드

**Files:**
- Modify: `common/infrastructure/exception/ErrorCode.java` (`// TALK` 섹션), `server/src/main/resources/i18n/messages_{ko,en,ja,zh,es}.properties` (`# --- 이야기 ---`)
- Modify: `client/lib/core/network/server_error_code.dart`
- Test: `ErrorMessageParityTest`

**Interfaces — Produces:** `TALK_POST_NOT_FOUND(404)`, `TALK_COMMENT_NOT_FOUND(404)`, `TALK_RULES_NOT_AGREED(403)`, `TALK_NOT_AUTHOR(403)`, `TALK_ROUTINE_NOT_SHAREABLE(400)`, `TALK_ALREADY_SHARED(409)`, `TALK_TEXT_TOO_LONG(400)`, `TALK_TEXT_NOT_ALLOWED(400)`, `TALK_NICKNAME_MASK_FAILED(500)`, `TALK_REPORT_DUPLICATED(409)`, `TALK_CANNOT_BLOCK_SELF(400)`, `TALK_IMAGE_NOT_FOUND(404)`

ko 문구(해요체): 내려간 글이에요 / 지워진 댓글이에요 / 이야기 이용 규칙에 먼저 동의해 주세요 / 내가 쓴 글만 고칠 수 있어요 / 이 일과는 이야기에 나눌 수 없어요 / 이미 이야기에 나눈 일과예요 / 300자까지 쓸 수 있어요 / 쓸 수 없는 말이 들어 있어요 / 잠시 뒤 다시 해 주세요 / 이미 신고했어요 / 내 글은 숨길 수 없어요 / 그림을 불러오지 못했어요. en은 같은 뜻으로, ja·zh·es는 en 문장 복사(기존 관례 확인 후).

- [ ] **Step 1: 실패하는 테스트** — `ErrorMessageParityTest`에 `ADDED_TALK_CODES` 목록(위 12개)과 `talkCodes_haveMessagesInAllLocales` 테스트, `codesAddedAfterOriginal_areAssertedSeparately` 합계에 `+ ADDED_TALK_CODES.size()`.
- [ ] **Step 2:** `./gradlew test --tests '*ErrorMessageParityTest*' --tests '*CrossStackContractTest*'` → FAIL
- [ ] **Step 3:** enum·properties·앱 `server_error_code.dart`(같은 섹션 순서) 추가
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** `/pro-commit`

### Task 3: 그림 사본 저장소 · 흐리게 · 사진 판정

**Files:**
- Create: `talk/infrastructure/storage/{TalkImageStorage,LocalFileTalkImageStorage}.java`, `talk/infrastructure/image/TalkImageBlurrer.java`
- Create: `common/infrastructure/properties/TalkProperties.java`
- Modify: `routine/infrastructure/storage/RoutineImageStorage.java`(+판정·가져오기 저장), `LocalFileRoutineImageStorage.java`
- Test: `talk/infrastructure/image/TalkImageBlurrerTest.java`, `talk/infrastructure/storage/LocalFileTalkImageStorageTest.java`, `routine/infrastructure/storage/LocalFileRoutineImageStorageTest.java`(있으면 추가, 없으면 생성)

**Interfaces — Produces:**
- `record TalkProperties(String imageStoragePath, String reportMailTo)` prefix `talk`, 기본 `data/talk-images`, `reportMailTo` 기본 null. `application.yml`: `talk.image-storage-path: ${ELUM_TALK_IMAGE_PATH:data/talk-images}`, `talk.report-mail-to: ${ELUM_TALK_REPORT_MAIL_TO:}`.
- `interface TalkImageStorage { String save(String postId, int stepOrder, byte[] bytes, String contentType); RoutineImageStorage.ImageContent read(String key); void deletePost(String postId); }` — 키 `{postId}/{stepOrder}.{jpg|png|webp}`, 기본 경로 밖 탈출 차단(Routine 구현과 같은 검사).
- `TalkImageBlurrer.blur(byte[] jpegOrPng) -> byte[]` (JPEG 0.85) — `javax.imageio`만. 긴 변 1024로 줄인 뒤 박스 블러 반경 = 긴 변의 4%(최소 12px) 3회.
- `RoutineImageStorage`에 추가:
  - `static boolean isGuardianUploadedPhoto(String key)` — 정규식 `^[^/]+/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\.jpg$`
  - `String saveImported(String stepId, ImageContent content)` — 키 `{stepId}/talk-{UUID}.{확장자}` (판정에 걸리지 않게 `talk-` 접두)

- [ ] **Step 1: 실패하는 테스트**
  - `blur_changesPixels_keepsSize`: 64×64 체크무늬 PNG → 결과 디코드 시 같은 크기, 인접 픽셀 차이 평균이 원본의 1/4 미만
  - `blur_invalidBytes_throwsInvalidType`: `new byte[]{1,2,3}` → `ROUTINE_STEP_IMAGE_INVALID_TYPE`
  - `isGuardianUploadedPhoto`: `"s1/0f8fad5b-d9cb-469f-a165-70867728950e.jpg"` true, `"batch/1.png"` false, `"s1/1.webp"` false, `"s1/talk-0f8fad5b-d9cb-469f-a165-70867728950e.jpg"` false, `null` false
  - `save_thenRead_roundTrips`, `save_pathEscape_rejected`(postId `"../x"` → 예외), `deletePost_removesDirectory` (임시 디렉터리)
  - `saveImported_keyHasTalkPrefix_andReadable`
- [ ] **Step 2:** `./gradlew test --tests '*TalkImageBlurrerTest*' --tests '*LocalFileTalkImageStorageTest*' --tests '*LocalFileRoutineImageStorageTest*'` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** `/pro-commit`

### Task 4: 올리기 (미리보기 · 저장)

**Files:**
- Create: `routine/application/service/RoutineShareService.java`, `routine/application/dto/RoutineShareSnapshot.java`
- Create: `talk/core/TalkTextRules.java`, `talk/application/service/TalkPostService.java`, request/response DTO
- Modify: `member/core/NicknamePolicy.java` (+`containsBlockedWord`), `member/application/service/MemberService.java` (+이용 규칙)
- Test: `routine/application/service/RoutineShareServiceTest.java`, `talk/application/service/TalkPostServiceTest.java`, `member/core/NicknamePolicyTest.java`(추가)

**Interfaces — Produces:**
- `RoutineShareSnapshot(String originalRoutineId, String title, AppLocale language, String profileNickname, List<StepSnapshot> steps)`; `record StepSnapshot(String stepId, int stepOrder, String title, String description, String imageKey, Integer pictogramId, String exampleImageId, boolean isGuardianPhoto)` — 타입은 `RoutineStep`의 실제 필드 타입에 맞춘다.
- `RoutineShareService.snapshotForShare(Caller caller, String routineId) -> RoutineShareSnapshot`
  - 오늘 일과 복사본이면 `sourceRoutineId`로 원본을 찾아 원본 기준으로 뜬다.
  - 거절(`TALK_ROUTINE_NOT_SHAREABLE`): `isExample`, `libraryHidden`, `talkPostId != null`, 상태 `PENDING_REVIEW`, 원본을 못 찾음.
  - 권한: `ProfileAccessGuard.checkRoutine(caller, profileId, createdBy, RoutineAction.VIEW)`.
- `RoutineShareService.readImage(String imageKey) -> RoutineImageStorage.ImageContent` (없으면 null, 던지지 않음)
- `MemberService.agreeTalkRules(String memberId)`, `MemberService.hasAgreedTalkRules(String memberId) -> boolean`, `MemberService.nicknamesOf(Collection<String> memberIds) -> Map<String,String>`, `MemberService.suspendedAmong(Collection<String> memberIds) -> Set<String>`
- `NicknamePolicy.containsBlockedWord(String text) -> boolean` — 기존 비교 키 규칙·허용 예외 재사용, 형식 검사 없음.
- `TalkTextRules.MAX_NOTE_LENGTH = 300`, `MAX_COMMENT_LENGTH = 300`; `static String normalizeNote(String raw)` (strip, 빈 값 null, 코드포인트 300 초과 `TALK_TEXT_TOO_LONG`, 제어문자는 줄바꿈 외 제거)
- `TalkPreviewRequest(String routineId)` → `TalkPreviewResponse(String title, List<PreviewStep> steps, boolean hasGuardianPhoto)`; `PreviewStep(String stepId, int stepOrder, String title, String description, boolean isGuardianPhoto)` (가린 뒤 글). 분류 제안은 앱이 한다(Task 13).
- `TalkPostCreateRequest(String routineId, String note, String category, List<String> blurredStepIds)` → `TalkPostDetailResponse`(Task 5에서 정의, 여기서는 id만 쓰는 `TalkPostCreatedResponse(String postId)`로 돌려준다)
- `TalkPostService.preview(Caller, TalkPreviewRequest) -> TalkPreviewResponse`
- `TalkPostService.create(Caller, TalkPostCreateRequest) -> TalkPostCreatedResponse`
  - 순서: 이용 규칙 동의 확인(`TALK_RULES_NOT_AGREED`) > 분류 파싱 > 한마디 정리 > 스냅샷 > 같은 원본 `VISIBLE` 글 있으면 `TALK_ALREADY_SHARED` > 이름 가리기(제목·카드 제목·카드 설명·한마디, `NicknamePlaceholder.mask(text, nickname, language)`; 예외 시 `TALK_NICKNAME_MASK_FAILED`) > 금칙어(가린 뒤 제목·한마디·카드 글, `TALK_TEXT_NOT_ALLOWED`) > 글 저장 > 카드별 그림 복사(사진이고 `blurredStepIds`에 있으면 `TalkImageBlurrer.blur`) > 스텝 저장.
  - `blurredStepIds`에 사진이 아닌 카드 id가 있으면 무시. 그림 읽기 실패한 카드는 `imageKey = null`로 저장하고 계속.
  - 그림 저장 중 예외 → 트랜잭션 롤백 + 이미 쓴 파일 `deletePost(postId)` (성공·실패 공통 정리는 `finally`가 아니라 catch 후 재던짐).

- [ ] **Step 1: 실패하는 테스트** (`TalkPostServiceTest`, Mockito, 고정 `Clock`)
  - `create_masksNicknameInTitleStepsAndNote`: 호칭 "하늘이", 제목 "하늘이 버스 타기", 카드 설명 "하늘이가 카드를 찍어요", 한마디 "하늘이는 좋아했어요" → 저장된 값에 "하늘이" 없음, "이룸이" 포함
  - `create_withoutNickname_keepsTextAndSucceeds`: 호칭 null
  - `create_maskThrows_rejectsWithMaskFailed`
  - `create_blurOnlySelectedPhotos`: 사진 2장(s1, s2), `blurredStepIds=[s2, aiStep]` → blur 1회(s2), s1은 원본 바이트 그대로 저장, aiStep은 그대로
  - `create_stepWithoutImage_copiesPictogramOnly`
  - `create_notAgreedRules_throws`, `create_alreadyShared_throws`, `create_unknownCategory_throwsInvalidInput`, `create_noteOver300_throwsTooLong`, `create_blockedWordInNote_throwsNotAllowed`
  - `preview_reportsGuardianPhotoAndMaskedText` (저장 호출 0회)
  - `RoutineShareServiceTest`: `snapshot_todayCopy_resolvesToOriginal`, `snapshot_example_rejected`, `snapshot_importedFromTalk_rejected`, `snapshot_pendingReview_rejected`, `snapshot_otherProfile_accessDenied`
  - `NicknamePolicyTest.containsBlockedWord_detectsInsideSentence` / `_allowsCleanSentence`
- [ ] **Step 2:** `./gradlew test --tests '*TalkPostServiceTest*' --tests '*RoutineShareServiceTest*' --tests '*NicknamePolicyTest*'` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 → PASS, `--tests '*ArchitectureRulesTest*'` PASS
- [ ] **Step 5:** `/pro-commit`

### Task 5: 피드 · 인기 · 상세 · 그림 · 이용 규칙 API

**Files:**
- Create: `talk/core/TalkCursor.java`, `talk/application/service/TalkFeedQueryService.java`, `talk/application/controller/{TalkController,TalkControllerDocs}.java`, 응답 DTO
- Modify: `member/application/controller/MemberController.java`(+Docs) — 이용 규칙 동의
- Test: `talk/application/service/TalkFeedQueryServiceTest.java`, `talk/core/TalkCursorTest.java`, `talk/application/controller/TalkSecurityTest.java`

**Interfaces — Produces:**
- `TalkCursor.encode(LocalDateTime createdAt, String id) -> String` (`"{ISO}|{id}"`), `TalkCursor.decode(String raw) -> Optional<TalkCursor>` (형식 틀리면 empty)
- `TalkPostSummaryResponse(String id, String authorNickname, boolean isMine, String title, String category, int stepCount, List<StepThumb> previewSteps /*앞 4장*/, String note, int helpfulCount, int commentCount, int importCount, LocalDateTime createdAt)`; `StepThumb(int stepOrder, boolean hasImage, Integer pictogramId, String exampleImageId, boolean isBlurred)`
- `TalkFeedPageResponse(List<TalkPostSummaryResponse> items, String nextCursor)`
- `TalkPostDetailResponse(... Summary 필드 + List<DetailStep> steps, boolean isHelpfulByMe, boolean isImportedByMe)`; `DetailStep(int stepOrder, String title, String description, boolean hasImage, Integer pictogramId, String exampleImageId, boolean isBlurred)`
- `TalkFeedQueryService.feed(Caller, String category, String cursor, Integer size, AppLocale viewerLocale) -> TalkFeedPageResponse` — `VISIBLE`, `language = viewerLocale`, 차단한 보호자·정지 회원 글 제외, 최신순, size+1 조회.
- `TalkFeedQueryService.popular(Caller, String category, AppLocale viewerLocale) -> List<TalkPostSummaryResponse>` — 최근 7일 `talk_import` 고유 보호자 수 내림차순 최대 10, 0건 글 제외.
- `TalkFeedQueryService.detail(Caller, String postId) -> TalkPostDetailResponse` — `VISIBLE` 아니면 `TALK_POST_NOT_FOUND`(관리자 경로 제외), 차단한 보호자 글도 404.
- `TalkFeedQueryService.stepImage(String postId, int stepOrder) -> ImageContent` — 글 숨김/삭제 또는 키 없음 `TALK_IMAGE_NOT_FOUND`.
- `TalkFeedQueryService.mySharedPosts(Caller) -> Map<String, String>` — 내 `VISIBLE` 글의 `sourceRoutineId -> postId`. 앱 입구(Task 18)가 "이미 나눈 일과"를 가리는 데 쓴다. routine 응답에 넣지 않는다(routine → talk 의존이 생기면 서비스 순환).
- 엔드포인트(`/api/talk`, 보호자 전용 기본값, 프로필 헤더 불필요):
  - `GET /posts?category=&cursor=&size=` · `GET /posts/popular?category=` · `GET /posts/mine/by-source-routine` · `GET /posts/{id}` · `GET /posts/{id}/steps/{stepOrder}/image`(`Cache-Control: private, max-age=86400`) · `POST /posts/preview` · `POST /posts`
  - `POST /api/member/talk-rules-agreement` → 204, `GET /api/member/talk-rules-agreement` → `{ "hasAgreed": bool }`
- 보는 사람 언어: 요청의 `Accept-Language`(기존 `AcceptLanguageInterceptor`가 붙임)를 서버 기존 `AppLocale` 변환 유틸로 읽는다(`AiCallContext`/`LocaleContextHolder` 중 기존 관례를 따른다).

- [ ] **Step 1: 실패하는 테스트**
  - `TalkCursorTest`: 왕복, `"garbage"` → empty, `null` → empty
  - `feed_malformedCursor_returnsFirstPage`, `feed_unknownCategory_throwsInvalidInput`, `feed_excludesBlockedAndSuspendedAuthors`, `feed_filtersByViewerLanguage`, `feed_sizeClampedTo50`, `feed_returnsNextCursorOnlyWhenMore`
  - `popular_ordersByDistinctImporters_last7Days_max10`
  - `detail_deletedPost_throwsNotFound`, `detail_blockedAuthor_throwsNotFound`, `detail_marksMineAndHelpful`
  - `detail_responseHasNoMemberId` — Jackson 직렬화 JSON에 `"memberId"`, `"email"`, `"username"` 문자열 없음
  - `TalkSecurityTest`: 토큰 없이 `GET /api/talk/posts` 401, 이룸이 기기 토큰 403 (`FeedbackSecurityTest`의 `@MockitoBean` 목록 복사)
- [ ] **Step 2:** `./gradlew test --tests '*TalkFeedQueryServiceTest*' --tests '*TalkCursorTest*' --tests '*TalkSecurityTest*'` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** `/pro-commit`

### Task 6: 내 글 고치기 · 내리기

**Files:** Modify `TalkPostService`, `TalkController`(+Docs). Test: `TalkPostServiceTest`.

**Interfaces — Produces:**
- `TalkPostUpdateRequest(String note, String category)` — 보낸 항목만 바꿈, 둘 다 null이면 `INVALID_INPUT_VALUE`
- `TalkPostService.update(Caller, String postId, TalkPostUpdateRequest) -> TalkPostDetailResponse`, `TalkPostService.delete(Caller, String postId)` — 작성자 아니면 `TALK_NOT_AUTHOR`, `DELETED`로 바꾸고 그림 파일 `deletePost`(커밋 뒤).
- `PATCH /api/talk/posts/{id}`, `DELETE /api/talk/posts/{id}` → 204

- [ ] **Step 1:** 테스트 `update_byOther_throwsNotAuthor`, `update_noteMaskedAndChecked`(한마디도 가리기·금칙어 거침), `delete_marksDeleted_andSchedulesImageRemoval`, `delete_thenShareAgain_allowed`(같은 원본 재공유 허용)
- [ ] **Step 2:** `./gradlew test --tests '*TalkPostServiceTest*'` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** `/pro-commit`

---

## Phase 2 — 서버: 일과관리로 가져오기

### Task 7: 가져오기

**Files:**
- Modify: `routine/application/service/RoutineShareService.java` (+`importToLibrary`), Create `routine/application/dto/RoutineImportDraft.java`
- Create: `talk/application/service/TalkImportService.java`, `TalkImportRequest`, `TalkImportResponse`; Modify `TalkController`
- Test: `RoutineShareServiceTest`, `talk/application/service/TalkImportServiceTest.java`

**Interfaces — Produces:**
- `RoutineImportDraft(String talkPostId, String title, AppLocale language, List<DraftStep> steps)`; `DraftStep(int stepOrder, String title, String description, Integer pictogramId, String exampleImageId, RoutineImageStorage.ImageContent image /*nullable*/)`
- `RoutineShareService.importToLibrary(Caller caller, String profileId, String groupId, RoutineImportDraft draft) -> String routineId`
  - `requireGuardianOf(memberId, profileId)`; `groupId`가 그 프로필 묶음이 아니면 `INVALID_INPUT_VALUE`.
  - 새 Routine: profile, `createdBy = caller.memberId()`, `status CONFIRMED`, `libraryOnly true`, `sourceRoutineId null`, `talkPostId`, `language`, `scheduledAt now`, 원문 칸은 제목. 묶음 없이 → `libraryOrder` 맨 앞(기존 칸들 +1, `RoutineLibraryService`의 순서 규칙 재사용), 묶음 → `groupOrder` 맨 뒤.
  - 저장(`RoutineRules.saveWithSpeech`) 뒤 그림 있는 카드마다 `saveImported(stepId, image)`로 키를 넣는다. 그림 저장 실패 카드는 그림 없이 둔다(로그, 계속).
- `TalkImportService.importToLibrary(Caller, String postId, TalkImportRequest(String profileId, String groupId)) -> TalkImportResponse(String routineId, String profileId)`
  - `VISIBLE` 아니면 `TALK_POST_NOT_FOUND` > 스냅샷 스텝 + `TalkImageStorage.read` 로 Draft 구성 > routine 위임 > `talk_import` 저장 > 이 보호자의 첫 가져가기면 `importCount + 1` > `TalkPostImportedEvent` 발행(Task 9에서 정의, 이 태스크에서는 발행 줄 없이 두고 Task 9에서 추가).
- `POST /api/talk/posts/{id}/import` (body `profileId`, `groupId?`) → 200 `TalkImportResponse`

- [ ] **Step 1: 실패하는 테스트**
  - `importToLibrary_createsLibraryOnlyConfirmedOriginal`: 상태 CONFIRMED, libraryOnly true, sourceRoutineId null, talkPostId 일치
  - `importToLibrary_noGroup_placedFirst`, `importToLibrary_withGroup_placedLast`, `importToLibrary_foreignGroup_throwsInvalidInput`
  - `importToLibrary_otherProfile_throwsAccessDenied`
  - `importToLibrary_stepWithoutImage_keepsPictogram`, `importToLibrary_imageSaveFails_continuesWithoutImage`
  - `TalkImportServiceTest`: `importToLibrary_deletedPost_throwsNotFound`, `importToLibrary_countsEachGuardianOnce`(같은 보호자 두 번 → importCount 1)
- [ ] **Step 2:** `./gradlew test --tests '*RoutineShareServiceTest*' --tests '*TalkImportServiceTest*'` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 + `--tests '*ArchitectureRulesTest*'` → PASS
- [ ] **Step 5:** `/pro-commit`

---

## Phase 3 — 서버: 반응 · 댓글 · 푸시

### Task 8: 도움돼요 · 댓글

**Files:** Create `talk/application/service/TalkReactionService.java`, `TalkReactionController`(+Docs), `TalkCommentRequest`, `TalkCommentResponse`, `TalkCommentPageResponse`. Test: `TalkReactionServiceTest`.

**Interfaces — Produces:**
- `TalkReactionService.markHelpful(Caller, String postId)` / `unmarkHelpful(...)` — 멱등, `helpfulCount` 재계산 대신 증감(유니크 충돌 시 무시).
- `TalkReactionService.comments(Caller, String postId, String cursor, Integer size) -> TalkCommentPageResponse` — 오래된 순, 차단·정지·숨김·삭제 제외. `TalkCommentResponse(String id, String authorNickname, boolean isMine, String body, LocalDateTime createdAt)`
- `TalkReactionService.addComment(Caller, String postId, TalkCommentRequest(String body)) -> TalkCommentResponse` — 이용 규칙 동의 확인 > 정리(300자, 빈 값 `INVALID_INPUT_VALUE`) > 금칙어 > 저장 > `commentCount + 1` > (Task 9) 이벤트
- `TalkReactionService.deleteComment(Caller, String commentId)` — 작성자만, `DELETED`, `commentCount - 1`
- `PUT/DELETE /api/talk/posts/{id}/helpful` → 204, `GET/POST /api/talk/posts/{id}/comments`, `DELETE /api/talk/comments/{id}` → 204

- [ ] **Step 1:** 테스트 `markHelpful_twice_countsOnce`, `unmarkHelpful_withoutMark_noop`, `addComment_notAgreed_throws`, `addComment_blank_throwsInvalidInput`, `addComment_over300_throwsTooLong`, `addComment_onDeletedPost_throwsNotFound`, `deleteComment_byOther_throwsNotAuthor`, `comments_excludeBlockedAuthors`
- [ ] **Step 2:** `./gradlew test --tests '*TalkReactionServiceTest*'` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** `/pro-commit`

### Task 9: 알림 타입 2개 · 푸시 · 설정

**Files:**
- Modify: `notification/core/NotificationType.java`, `NotificationDraft.java`, Create `notification/core/event/{TalkPostCommentedEvent,TalkPostImportedEvent}.java`
- Modify: `NotificationEventListener.java`, `PushMessageFactory.java`, `PushDispatcher.java`, `NotificationSettingRequest/Response`, `NotificationSettingService.java`, `i18n/push-messages_{ko,en,ja,zh,es}.properties`
- Modify: `TalkReactionService.addComment`, `TalkImportService.importToLibrary` (이벤트 발행)
- Test: `NotificationEventListenerTest`(기존에 추가), `PushMessageFactoryTest`(기존에 추가), `TalkReactionServiceTest`, `TalkImportServiceTest`

**Interfaces — Produces:**
- `TALK_POST_COMMENTED`, `TALK_POST_IMPORTED`
- `record TalkPostCommentedEvent(String postId, String authorMemberId, String actorMemberId, String postTitle)`, `record TalkPostImportedEvent(String postId, String authorMemberId, String actorMemberId, String postTitle)`
- `NotificationDraft.talkPostCommented(postId, actorMemberId, now)` groupKey `"TALK_POST_COMMENTED:" + postId`, `talkPostImported(...)` groupKey `"TALK_POST_IMPORTED:" + postId`, `profileId = null`, `targetId = postId`.
- 수신자 `List.of(authorMemberId)`, `actor == author`면 기록하지 않음.
- 푸시 ko: `push.talkPostCommented="{0}"에 댓글이 {1}개 달렸어요`, `push.talkPostImported=보호자 {1}명이 "{0}"을 가져갔어요` (조사는 기존 push 문구의 받침 처리 관례를 따른다). `{1}`은 `Notification.count`.
- 설정 매핑: `TALK_POST_COMMENTED -> talkCommentedEnabled`, `TALK_POST_IMPORTED -> talkImportedEnabled`. 응답·요청에 필드 추가(옛 앱이 몰라도 무시되게 요청 필드는 null이면 그대로).
- 알림 목록 쿼리가 `profileId`로 거르는지 확인. 거른다면 `profileId IS NULL`(계정 단위) 알림도 포함하도록 고친다 — 기존 `FEEDBACK_RESOLVED`가 같은 계정 단위이므로 그 처리 방식을 그대로 따른다.

- [ ] **Step 1:** 테스트 `onTalkPostCommented_recordsForAuthorOnly`, `onTalkPostCommented_selfComment_skipped`, `talkCommentPush_groupsByPost`(같은 글 3번 → count 3, 한 줄), `buildBody_talkPostImported_ko`, `isTypeEnabled_talkCommented_respectsSetting`, `addComment_publishesEvent`, `importToLibrary_publishesEvent`
- [ ] **Step 2:** `./gradlew test --tests '*NotificationEventListenerTest*' --tests '*PushMessageFactoryTest*' --tests '*PushDispatcherTest*' --tests '*TalkReactionServiceTest*' --tests '*TalkImportServiceTest*'` → FAIL
- [ ] **Step 3:** 구현 (switch가 exhaustive라 빠진 곳은 컴파일이 알려 준다)
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** `/pro-commit`

---

## Phase 4 — 서버: 신고 · 차단 · 메일 · 관리자 · 탈퇴

### Task 10: 신고 · 차단 · 신고 메일

**Files:**
- Modify: `server/build.gradle` (+`org.springframework.boot:spring-boot-starter-mail`)
- Create: `talk/infrastructure/mail/{TalkReportMailer,SmtpTalkReportMailer,NoOpTalkReportMailer,TalkReportMailConfig}.java`, `talk/application/service/TalkModerationService.java`, `TalkModerationController`(+Docs), `TalkReportRequest`, `TalkBlockRequest`, `TalkBlockResponse`, `notification`과 무관한 `talk/core/event/TalkReportedEvent.java`
- Modify: `application.yml` (`spring.mail.*` 환경 변수)
- Test: `TalkModerationServiceTest`, `talk/infrastructure/mail/SmtpTalkReportMailerTest.java`

**Interfaces — Produces:**
- `TalkModerationService.report(Caller, TalkReportRequest(String targetType, String targetId, String reason))` — 대상 없음 404, 같은 신고자 중복 `TALK_REPORT_DUPLICATED`, 저장 후 `TalkReportedEvent(reportId)` 발행. **자동 숨김 없음.**
- `TalkModerationService.block(Caller, TalkBlockRequest(String postId, String commentId))` — 둘 중 하나로 글쓴이를 찾는다, 자기 자신 `TALK_CANNOT_BLOCK_SELF`, 멱등. `unblock(Caller, String blockId)`. `blocks(Caller) -> List<TalkBlockResponse(String blockId, String nickname, LocalDateTime createdAt)>`
- `PUT /api/talk/blocks`(body) → 204, `DELETE /api/talk/blocks/{blockId}` → 204, `GET /api/talk/blocks`, `POST /api/talk/reports` → 204
- `interface TalkReportMailer { void sendReportNotice(TalkReportNotice notice); }`, `record TalkReportNotice(String reportId, String targetType, String reasonLabel, String postTitle, String excerpt /*최대 200자*/, String adminUrl)` — 신고자 정보 없음.
- 빈 선택: `talk.report-mail-to`와 `spring.mail.host`가 모두 있으면 `SmtpTalkReportMailer`, 아니면 `NoOpTalkReportMailer`(경고 로그 1회).
- 리스너: `@Async(AsyncConfig.NOTIFICATION_EXECUTOR) @TransactionalEventListener(AFTER_COMMIT)`에서 메일 발송, 실패는 `[talk report mail] failed : {reportId}` 로그만.
- 메일 제목 `[이룸] 이야기 신고 접수 : {reasonLabel}`, 본문 평문 한국어, 관리자 링크 `https://api.elum.chuseok22.com/admin/talk/posts/{postId}`(기준 주소는 기존 설정값이 있으면 그것, 없으면 `talk.admin-base-url` 프로퍼티로).
- `application.yml`: `spring.mail.host: ${ELUM_MAIL_HOST:}`, `port: ${ELUM_MAIL_PORT:587}`, `username: ${ELUM_MAIL_USERNAME:}`, `password: ${ELUM_MAIL_PASSWORD:}`, `properties.mail.smtp.auth: true`, `properties.mail.smtp.starttls.enable: true`. 값은 운영 env(`BACKEND_ENV_FILE` secret)에만 — Task 22에서 사용자에게 받는다.

- [ ] **Step 1:** 테스트 `report_duplicate_throws`, `report_doesNotHidePost`(3명 신고 후에도 VISIBLE), `report_publishesEvent`, `block_self_throws`, `block_twice_idempotent`, `blocks_listsNicknames`, `SmtpTalkReportMailerTest.buildsMessageWithoutReporterInfo`(JavaMailSender mock, 본문에 reporter id 없음, excerpt 200자 자름), `mailFailure_doesNotPropagate`
- [ ] **Step 2:** `./gradlew test --tests '*TalkModerationServiceTest*' --tests '*SmtpTalkReportMailerTest*'` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** `/pro-commit`

### Task 11: 관리자 화면

**Files:**
- Create: `admin/application/controller/AdminTalkController.java`, `admin/application/list/{AdminTalkPostList,AdminTalkReportList}.java`, `talk/application/service/TalkAdminService.java`
- Create: `templates/admin/{talk,talk-detail,talk-reports}.html`; Modify `templates/admin/fragments/admin-layout.html` (운영 그룹, 의견 관리 아래 `이야기`)
- Test: `AdminTalkControllerTest`, `AdminTalkTemplateTest` (Feedback 쌍을 복사해 맞춘다)

**Interfaces — Produces:**
- `GET /admin/talk/posts`(상태 필터 VISIBLE/HIDDEN_BY_ADMIN/DELETED, 신고 수 정렬), `GET /admin/talk/posts/{id}`(카드·그림·한마디·댓글·신고 목록), `POST /admin/talk/posts/{id}/hide`, `/restore`, `POST /admin/talk/comments/{id}/hide`, `/restore`, `GET /admin/talk/reports?resolved=false`, `POST /admin/talk/reports/{id}/resolve`, `GET /admin/talk/posts/{id}/steps/{stepOrder}/image`(`no-store`, `nosniff`, 숨김·삭제 글도)
- 사이드 메뉴 `이야기` 옆 미처리 신고 수 배지(0이면 숨김).
- 글쓴이는 닉네임 + 기존 회원 상세 링크(`/admin/members/{memberId}`)로만 연결.

- [ ] **Step 1:** 테스트 `posts_listsWithReportCount`, `hide_setsHiddenByAdmin`, `restore_setsVisible`, `stepImage_hiddenPost_stillServed`, `layout_hasTalkMenu`
- [ ] **Step 2:** `./gradlew test --tests '*AdminTalk*'` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 + `--tests '*ArchitectureRulesTest*'` → PASS
- [ ] **Step 5:** `/pro-commit`

### Task 12: 탈퇴 정리

**Files:** Create `talk/application/service/TalkCleanupService.java`; Modify `MemberService.withdraw`(:219), `WithdrawnMemberService.purge`(:122). Test: `TalkCleanupServiceTest`, `MemberServiceTest`(호출 확인).

**Interfaces — Produces:** `TalkCleanupService.deleteAllOf(String memberId)` — 그 회원의 글(그림 디렉터리 포함, 커밋 뒤)·스텝·댓글·도움돼요·신고(신고자이거나 대상 글이 그의 글)·차단(양방향)·`talk_import` 삭제, 남의 글 `helpfulCount`·`commentCount`·`importCount`를 다시 센다. `routine.talk_post_id`는 건드리지 않는다.

- [ ] **Step 1:** 테스트 `deleteAllOf_removesOwnContent_andRecountsOthers`, `withdraw_callsTalkCleanup`, `purge_callsTalkCleanup`
- [ ] **Step 2:** `./gradlew test --tests '*TalkCleanupServiceTest*' --tests '*MemberServiceTest*' --tests '*WithdrawnMemberServiceTest*'` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** `/pro-commit`

---

## Phase 5 — 앱

> 앱에는 단위 테스트가 없다. 태스크마다 검증은 `cd client && flutter analyze <바꾼 파일들>` 0 issue + `dart run tool/check_hangul_literals.dart lib` 0줄 + `dart run tool/check_layer_imports.dart` 통과. 화면 확인은 Task 22에서 시뮬레이터로 한 번에.

### Task 13: 데이터 계층 · 분류 이름

**Files:**
- Create: `client/lib/features/talk/domain/{talk_post.dart,talk_comment.dart,talk_category_suggester.dart}`, `data/{talk_repository.dart,talk_image_repository.dart}`
- Modify: `client/lib/l10n/app_ko.arb` (분류 6개 이름·힌트 교체, 이야기 문구), `routine_template.dart` `hintOf`
- Modify: `client/lib/features/guardian/presentation/widgets/routine_template_sheet.dart`(이름 바뀐 것만 확인, 코드 변경 없을 수 있음)

**Interfaces — Produces:**
- 모델(`fromJson`만, 방어적 파싱 — 형식이 틀린 항목은 건너뛴다): `TalkPostSummary`, `TalkPostDetail`, `TalkStep`, `TalkComment`, `TalkFeedPage(items, nextCursor)`, `TalkPreview`, `TalkBlockEntry`
- `class TalkRepository` (`Provider<TalkRepository>((ref) => TalkRepository(ref.watch(dioProvider)))`, 계정 단위 API라 `Options(extra: {ProfileHeaderInterceptor.skipKey: true})`, 실패는 `NotificationRepository._call`처럼 `AppFailure.of(e)`로 던짐):
  `fetchFeed({String? category, String? cursor})`, `fetchPopular({String? category})`, `fetchMySharedPosts()`, `fetchDetail(String postId)`, `preview(String routineId)`, `create({routineId, note, category, blurredStepIds})`, `update(postId, {note, category})`, `delete(postId)`, `markHelpful/unmarkHelpful(postId)`, `fetchComments(postId, {cursor})`, `addComment(postId, body)`, `deleteComment(commentId)`, `importToLibrary(postId, {required profileId, String? groupId})`, `report({targetType, targetId, reason})`, `block({postId, commentId})`, `unblock(blockId)`, `fetchBlocks()`, `hasAgreedRules()`, `agreeRules()`
- `TalkImageRepository.fetch(postId, stepOrder) -> Future<Uint8List?>` — `CardImageRepository`처럼 인증 Dio + 디스크 캐시(키 `talk/{postId}/{stepOrder}`), 던지지 않음.
- `RoutineTemplateCategory? suggestTalkCategory(String routineTitle, AppLocalizations l10n)` — `routineTemplates` 각 템플릿 이름(현재 화면 언어)과 제목의 공통 낱말(공백 기준, 2글자 이상) 수가 가장 많은 템플릿의 분류. 0이면 null.
- ARB 분류: `routineTemplateCategorySelfCare: "생활 습관"`, `…DailyFlow: "하루 순서"`, `…Household: "집안일"`, `…Community: "바깥 활동"`, `…Learning: "공부"`, `…Feelings: "감정·관계"`. 힌트(예시 3개): 양치 · 세수 · 옷 입기 / 아침 준비 · 하교 후 · 잠자리 (여러 일을 차례로) / 방 정리 · 그릇 치우기 · 빨래 개기 / 버스 타기 · 물건 사기 · 병원 가기 / 숙제 시작 · 이름 쓰기 · 책 읽기 / 감정 카드 · 인사 · 차례 기다리기.

- [ ] **Step 1:** 모델·repository·제안 함수·ARB 작성, `flutter gen-l10n`
- [ ] **Step 2:** `flutter analyze lib/features/talk lib/features/guardian/domain` + 규칙 도구 2개 → 0
- [ ] **Step 3:** `/pro-commit`

### Task 14: 피드 화면 · 탭 교체

**Files:** Create `application/{talk_feed_controller.dart,talk_popular_provider.dart}`, `presentation/talk_feed_screen.dart`, `widgets/{talk_post_card,talk_popular_row,talk_category_chips,talk_step_image}.dart`; Modify `core/router/routes_guardian.dart`(talk 브랜치), `routes.dart`(`guardianTalkPost = '/guardian/talk/posts/:postId'`, `guardianTalkShare = '/guardian/talk/share'`), `guardian_coming_soon_screen.dart`(다른 칸이 안 쓰면 삭제 + `AppAssets.storiesComingSoonLumi` 미사용이면 정리).

**Interfaces — Produces:**
- `talkFeedControllerProvider = AsyncNotifierProvider.autoDispose.family<TalkFeedController, TalkFeedState, String?>` (인자: 분류 serverValue, 전체는 null). 상태·`loadMore`·`refresh`는 `NotificationListController` 방식 그대로(`nextCursor`, `isLoadingMore`, `hasLoadMoreFailed`, id 중복 제거).
- `talkPopularProvider = FutureProvider.autoDispose.family<List<TalkPostSummary>, String?>`
- 화면: 헤더(제목 + `+ 올리기`) / 분류 칩(전체 + 6) / 인기 줄(0건이면 숨김, 실패해도 숨김) / 최신 목록 무한 스크롤 / 당겨서 새로고침 / 빈 상태(일러스트 + "아직 나눈 일과가 없어요" + "첫 일과를 나눠 보세요" 버튼) / 첫 페이지 실패 `ElumErrorView(errorCode: failure.badgeOr('E-TALK-001'), onRetry:)` / 추가 페이지 실패는 목록 끝 재시도 줄.
- `TalkStepImage(postId, step)` — 그림 있으면 `TalkImageRepository`, 없거나 실패면 픽토그램 → 예시 그림 → 빈 칸(기존 `CardImage` 대체 순서와 같게).
- "내 일과로" 버튼은 Task 17 시트를 연다.

- [ ] **Step 1:** 구현 (ARB 키: `talkTitle`, `talkWriteButton`, `talkCategoryAll`, `talkPopularTitle`, `talkPopularPeriod`, `talkPopularImportCount`(plural), `talkLatestTitle`, `talkEmptyTitle`, `talkEmptyAction`, `talkImportButtonShort`, `talkHelpfulCount`, `talkCommentCount`, `talkLoadMoreRetry`, 시간 표기는 `date_labels.dart` 재사용)
- [ ] **Step 2:** analyze + 규칙 도구 → 0
- [ ] **Step 3:** `/pro-commit`

### Task 15: 상세 · 도움돼요 · 댓글 · ⋯ 메뉴 · 신고 · 숨기기

**Files:** Create `application/{talk_detail_controller.dart,talk_comment_controller.dart}`, `presentation/talk_detail_screen.dart`, `widgets/{talk_comment_list,talk_more_menu,talk_report_sheet,talk_block_dialog}.dart`; Modify `routes_guardian.dart`(셸 밖 `GoRoute(path: Routes.guardianTalkPost, pageBuilder: slidePage(...))`). 숨긴 보호자 목록: `features/talk/presentation/talk_blocked_guardians_screen.dart` + 내 정보 설정에 `SettingsTile` 한 줄 + `Routes.guardianTalkBlocks`.

**Interfaces — Produces:**
- `talkDetailControllerProvider = AsyncNotifierProvider.autoDispose.family<TalkDetailController, TalkPostDetail, String>` — `toggleHelpful()`(낙관적 갱신, 실패 시 되돌리고 토스트), `delete()`, `update(note, category)`.
- 댓글: 목록 + 하단 입력(`ElumTextField`는 한 줄 전용이므로 여러 줄 입력은 기존 의견 보내기 화면 입력 위젯을 재사용하고, 없으면 `TextField` + 토큰 스타일). 보내기 실패 시 입력 유지 + `showFailure(fallbackCode: 'E-TALK-030')`. 첫 댓글이면 Task 16의 규칙 시트를 먼저.
- ⋯ 메뉴(`showElumSheet`): 남의 글 → 신고하기 · 이 보호자 글 숨기기 / 내 글 → 고치기(한마디·분류 시트) · 내리기(확인 대화상자). 댓글 길게 누르기: 남의 댓글 → 신고 · 숨기기 / 내 댓글 → 지우기.
- 신고 시트: 사유 4개(이룸이나 가족 정보가 보여요 / 기분 나쁜 말이 있어요 / 광고나 홍보예요 / 그 밖의 이유) → 성공 토스트 "신고했어요", 중복이면 서버 문구.
- 숨기기 대화상자: "{닉네임}님 글을 숨길까요?" / "이 보호자의 글과 댓글이 나에게 안 보여요. 상대방은 알 수 없어요. 내 정보 › 숨긴 보호자에서 다시 볼 수 있어요." → 성공 시 피드 provider invalidate + 상세 닫기.
- 내려간 글(`TALK_POST_NOT_FOUND`): 빈 상태 "내려간 글이에요".

- [ ] **Step 1:** 구현
- [ ] **Step 2:** analyze + 규칙 도구 → 0
- [ ] **Step 3:** `/pro-commit`

### Task 16: 올리기 흐름 (규칙 동의 · 사진 고르기 · 분류 · 미리보기)

**Files:** Create `application/{talk_share_controller.dart,talk_rules_provider.dart}`, `presentation/talk_share_screen.dart`, `widgets/{talk_rules_sheet,talk_photo_blur_picker,talk_category_picker,talk_routine_picker}.dart`; Modify `routes_guardian.dart`(`Routes.guardianTalkShare`, `extra`로 `String? routineId`).

**Interfaces — Produces:**
- `Future<bool> ensureTalkRulesAgreed(BuildContext context, WidgetRef ref)` — 서버 `hasAgreedRules` 확인, 아니면 규칙 시트(규칙 3줄: 얼굴·이름·학교·집 주소가 보이지 않게 / 다른 보호자를 존중, 비난·광고·홍보 금지 / 진단명·병원 정보 적지 않기 + 체크 + "동의하고 계속하기"), 동의 시 `agreeRules()` 후 true. 올리기 시작과 첫 댓글 둘 다 이 함수를 거친다.
- `TalkShareController` 상태: `routineId`, `preview`, `blurChoiceByStepId: Map<String,bool?>`(null = 아직 안 고름), `note`, `category`, `isSubmitting`.
  - 단계: ① 일과 고르기(입구가 routineId를 주면 건너뜀; 목록은 일과관리 원본 중 예시·숨김·`talkPostId` 있는 것 제외 — 앱 `Routine` 모델에 `talkPostId` 필드 추가) ② 사진 고르기(`preview.hasGuardianPhoto`일 때만, 사진 카드마다 흐리게/그대로, 모두 고르기 전 "다음" 비활성, 고르면 미리보기에 `ImageFiltered(blur)` — 표시용일 뿐 실제 블러는 서버) ③ 분류(제안값 `suggestTalkCategory` 미리 선택, 칸마다 이름 + 힌트) · 한마디(300자 카운터, 안내 "다른 사람 이름·연락처는 적지 말아 주세요") · 가린 카드 미리보기.
  - 올리기 성공 → 상세로 교체 이동 + 토스트 "이야기에 올렸어요" + 피드 invalidate. 실패 → 입력 유지, `showFailure(fallbackCode: 'E-TALK-010')`.

- [ ] **Step 1:** 구현
- [ ] **Step 2:** analyze + 규칙 도구 → 0
- [ ] **Step 3:** `/pro-commit`

### Task 17: 일과관리로 넣기 시트 · "새로" · "이야기에서"

**Files:** Create `widgets/talk_import_sheet.dart`; Modify `client/lib/shared/models/routine.dart`(+`talkPostId`), `features/guardian/presentation/widgets/library_routine_tile.dart`, `routine_detail_sheet.dart`(가져온 일과 머리 안내), `features/guardian/application/routine_library_controller.dart`(새 칸 스크롤 대상), 로컬 저장 키 1개(`StorageKeys`에 `talkImportedSeenRoutineIds`).

**Interfaces — Produces:**
- `Future<void> showTalkImportSheet(BuildContext context, WidgetRef ref, TalkPostSummary post)` — 이룸이 목록(기존 보호자 프로필 목록 provider) 2명 이상일 때만 이룸이 줄, 묶음 줄(기존 묶음 provider, 기본 "묶음 없이"), 이룸이 0명이면 "이룸이를 먼저 연결해 주세요" + 연결 화면 버튼.
- 성공 → 토스트 "{호칭} 일과관리에 넣었어요" + "보러 가기"(일과관리 탭 이동 + 해당 칸 스크롤), 상세 버튼 "✓ 일과관리에 넣었어요"(다시 누르면 또 넣기), 일과관리 provider invalidate. 실패 → 시트 유지 + `showFailure(fallbackCode: 'E-TALK-020')`.
- 일과관리 칸: `talkPostId != null`이면 이름 아래 "이야기에서", 로컬 "본 적 없음"이면 주황 테두리 + "새로" 배지(상세를 한 번 열면 본 것으로 저장). 색은 토큰(없으면 `AppColors`에 `accentNew` 토큰 추가).
- 상세 머리: "📖 {닉네임}님이 이야기에 나눈 일과예요" + 원래 한마디 + "원래 글 보기"(`fetchDetail` 404면 링크 숨김). 닉네임·한마디는 상세를 열 때 `fetchDetail(talkPostId)`로 받는다.

- [ ] **Step 1:** 구현
- [ ] **Step 2:** analyze + 규칙 도구 → 0
- [ ] **Step 3:** `/pro-commit`

### Task 18: 입구 2곳 (홈 · 일과관리 ⋯)

**Files:** Modify `features/guardian/presentation/widgets/today_routine_section.dart`(끝낸 일과 카드 아래 링크), `widgets/library_quick_menu.dart`(`LibraryMenuAction.shareToTalk`), `routine_manage_screen.dart`(처리), 로컬 저장 키 `talkShareHintDismissedRoutineIds`.

**Interfaces — Consumes:** `TalkRepository.fetchMySharedPosts() -> Future<Map<String, String>>` (Task 13에 추가, `GET /api/talk/posts/mine/by-source-routine`), `talkMySharedPostsProvider = FutureProvider.autoDispose<Map<String, String>>`(올리기·내리기 뒤 invalidate). 실패하면 빈 맵으로 보고 입구를 보여 준다(올리기 시 서버가 `TALK_ALREADY_SHARED`로 막는다).

**Interfaces — Produces:**
- 홈: `_isFinished(routine)`이고, 원본 id(`routine.sourceRoutineId ?? routine.id`)가 공유 맵에 없고, 닫은 적 없으면 "📖 이야기에 공유해 보기 ›" + ✕. 누르면 `Routes.guardianTalkShare`(extra: 원본 id).
- 일과관리 ⋯: 예시 아님 · `talkPostId == null`이면 메뉴 한 줄 — 맵에 없으면 "이야기에 공유하기", 있으면 "내 글 보기"(그 postId 상세로).

- [ ] **Step 1:** 앱 입구 구현
- [ ] **Step 2:** analyze + 규칙 도구 → 0
- [ ] **Step 3:** `/pro-commit`

### Task 19: 앱 알림 · 설정

**Files:** Modify `features/notification/domain/notification_type.dart`(+`talkPostCommented('TALK_POST_COMMENTED')`, `talkPostImported('TALK_POST_IMPORTED')`), `application/notification_navigator.dart`(`context.push(Routes.guardianTalkPost` with `targetId`), `presentation/widgets/notification_copy.dart`, `domain/notification_settings.dart`, `application/notification_settings_controller.dart`(`NotificationSettingField` +2), `widgets/notification_setting_rows.dart`(라벨 "이야기: 내 글에 댓글이 달렸을 때" · "이야기: 내 글을 가져갔을 때").

- [ ] **Step 1:** 구현 (푸시 탭 진입도 같은 navigator를 지나는지 확인)
- [ ] **Step 2:** analyze + 규칙 도구 → 0
- [ ] **Step 3:** `/pro-commit`

### Task 20: 개인정보처리방침 사본 맞추기 (#906)

**Files:** Modify `client/lib/features/auth/domain/consent_documents.dart`(privacy 본문 = 운영 DB 2026-10-20판), `server/src/main/resources/consent/privacy*.txt`(dart에서 기계로 떠냄).

- [ ] **Step 1:** `curl -s https://api.elum.chuseok22.com/api/consents/documents`의 privacy 본문으로 dart 본문 교체, 버전 문자열 `2026-10-20`
- [ ] **Step 2:** 서버 txt를 dart에서 떠내고 글자 수 대조(운영 DB 6,821자, txt는 끝 줄바꿈 1자 차이 허용) + `python3 tool/check_public_pages.py` "어긋난 곳 없음"
- [ ] **Step 3:** `/pro-commit` (#906에도 커밋 링크 댓글)

---

## Phase 6 — 검증 · 마무리

### Task 21: 전체 정적 검증

- [ ] **Step 1:** 다른 세션의 무거운 작업 확인(`ps aux | grep -E "gradle|flutter|xcodebuild" | grep -v grep`). 있으면 끝날 때까지 미룬다.
- [ ] **Step 2:** `cd server && ./gradlew test` → 전부 PASS (1회)
- [ ] **Step 3:** `cd client && flutter analyze` → No issues, `dart run tool/check_hangul_literals.dart lib` 0줄, `dart run tool/check_layer_imports.dart` 통과
- [ ] **Step 4:** `/pro-review`로 브랜치 전체 리뷰, Critical·Major 고친 뒤 해당 테스트만 재실행

### Task 22: 실기기 흐름 확인 · 배포 준비

- [ ] **Step 1:** 로컬 서버(`elum-local-db-rehearsal` 메모 방식, AI 키 가짜) + iOS 시뮬레이터 두 대(보호자 A·B, `/pro-launch`, Maestro)로: A 올리기(사진 흐리게 1장·그대로 1장) → B 피드·인기·상세 → B 일과관리에 넣기 → "새로"·"이야기에서" 확인 → B 보내기 → 이룸이 화면 확인 → B 댓글 → A 알림 목록·푸시(로컬은 FCM 없으면 목록만) → B 신고(메일은 NoOp 로그 확인) → B 숨기기 → 피드에서 사라짐 → A 내리기 → B 상세 "내려간 글이에요". 라이트·다크 각각 캡처, 실패 시 에러 코드 노출 확인(네트워크 끊고 피드).
- [ ] **Step 2:** 결과를 이슈에 캡처와 함께 남긴다(`/pro-github upload-image`).
- [ ] **Step 3:** 사용자에게 받는다: 운영 메일 설정 값(`ELUM_TALK_REPORT_MAIL_TO`, `ELUM_MAIL_*`) → `/pro-github secrets`로 `BACKEND_ENV_FILE` 갱신. 값은 대화·커밋·이슈에 남기지 않는다.
- [ ] **Step 4:** 푸시 → `@projectops app build <브랜치명>` 댓글(앱 바뀐 이슈 규칙) → 테스트 빌드로 사용자 확인.
- [ ] **Step 5:** 화면 문구 한 장씩 사용자 확인(사용자 요청) → ARB 수정 → 재빌드 댓글.
- [ ] **Step 6:** 디자이너 요청(`/pro-design-brief`)은 사용자가 원하면 별도 이슈.
- [ ] **Step 7:** 배포는 사용자가 "배포해줘"라고 할 때만: main 최신화 → `/pro-changelog-deploy`(앱 심사 제출과 직결) → 운영 API 실측 → `/pro-report` → 라벨 `작업완료` + 닫기(#906도 함께).
