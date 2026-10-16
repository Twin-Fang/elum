# 카드 음성 미리 만들기 구현 계획 (#675)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 단계 음성을 서버가 Supertonic으로 미리 만들어 저장하고, 안드로이드 앱은 그 음성을 폰에 파일로 캐시해 재생한다.

**Architecture:** 서버는 커밋 뒤 단일 스레드 대기열에 넣고, 대기열이 AI 서버를 부른다. 결과를 로컬 디스크에 저장하고 `routine_step.speech_path`를 갱신한다. 주기 작업이 빠진 것을 메운다. 앱은 `GET .../speech`로 받아 `card_images/speech/{stepId}/{열쇠해시}.wav`에 캐시하고, 안드로이드에서만 기기 음성보다 먼저 재생한다.

**Tech Stack:** Spring Boot (RestClient, JPA, Flyway, `@Scheduled`), JUnit5와 Mockito / Flutter (Riverpod, Dio, audioplayers, cryptography)

**Spec:** `docs/superpowers/specs/2026-10-16-card-speech-pregeneration-design.md`

## Global Constraints

- 엔진은 `supertonic`, 목소리는 `F1`이다. 일과 언어가 `ko`(또는 null)일 때만 만든다.
- AI 서버로 가는 동시 요청은 1건이다.
- 읽을 문장은 `{표시 제목}. {설명}`이다. 표시 제목은 제목이 비면 설명이다.
- TTS 키와 주소는 `local-llm.api-key`·`local-llm.base-url`을 그대로 쓴다. 실측에서 앱 `ELUM_TTS_API_KEY`와 같은 값이었다. 그래서 배포 Secret을 바꾸지 않는다.
- 운영 저장 경로 `data/routine-speech`는 `/app` 마운트 아래에 있어 재배포해도 남는다. 그림 경로 `data/routine-images`와 같다.
- 아이폰 재생 순서는 바꾸지 않는다.
- 앱 캐시는 `CardImageDiskCache` 폴더 아래 `speech/`에 둔다. 그러면 로그아웃·탈퇴·세션 만료 때 기존 `clear()`가 함께 지운다(호출 4곳을 손대지 않는다).
- 주석은 한국어 한 줄 요약과 블록 머리글로 쓴다. 로그 접두사는 `[routine speech]`다.
- 문서와 테스트로 새 ErrorCode를 늘리지 않는다. 음성이 없으면 컨트롤러가 404를 바로 돌려준다.

## Review Focus

1. 생성 중 글 수정: 저장 직전에 문장 해시를 다시 비교하고, 다르면 버린다 (Task 3 시험).
2. 단계·일과 삭제 직후 늦게 끝난 생성: 갱신 0행이면 파일을 지운다 (Task 3 시험).
3. AI 서버 503·타임아웃: 예외가 밖으로 나가지 않고 `speech_path`는 null로 남는다. 주기 작업이 다시 넣는다 (Task 3·4 시험).
4. 앱이 받은 응답이 WAV가 아님(HTML 오류 페이지 등): 캐시하지 않고 다음 순서로 넘어간다 (Task 6 시험).
5. 같은 카드를 빠르게 연타: 받기는 1번, 재생은 이전 소리를 멈추고 1번 (Task 6·7 시험).

---

### Task 1: DB 컬럼, 엔티티, 응답 필드, 문장 규칙

**Files:**
- Create: `server/src/main/resources/db/migration/V37__add_routine_step_speech_path.sql`
- Create: `server/src/main/java/com/chuseok22/elumserver/routine/core/RoutineStepSpeechText.java`
- Modify: `RoutineStep.java` (`speechPath` 필드), `RoutineStepResponse.java` (`speechPath`)
- Test: `server/src/test/java/com/chuseok22/elumserver/routine/core/RoutineStepSpeechTextTest.java`

**Interfaces — Produces:**
- `RoutineStepSpeechText.of(String title, String description) -> String`
- `RoutineStepSpeechText.hashOf(String text) -> String` (SHA-256 hex 앞 16자)
- `RoutineStep#getSpeechPath()/setSpeechPath(String)`

- [ ] 시험: 제목이 있으면 `제목. 설명`, 제목이 null이나 공백이면 `설명. 설명`. 같은 문장이면 같은 해시이고, 길이는 16이다.
- [ ] 구현 후 `./gradlew test --tests '*RoutineStepSpeechTextTest'` 통과.

### Task 2: 음성 저장소와 Supertonic 클라이언트

**Files:**
- Create: `routine/infrastructure/storage/RoutineStepSpeechStorage.java`, `LocalFileRoutineStepSpeechStorage.java`
- Create: `ai/infrastructure/client/SupertonicTtsClient.java`
- Modify: `common/infrastructure/properties/RoutineProperties.java` (`speechStoragePath`, 기본 `data/routine-speech`)
- Test: `routine/infrastructure/storage/RoutineStepSpeechStorageTest.java`

**Interfaces — Produces:**
- `String save(String stepId, String textHash, byte[] wav)`: 열쇠 `{stepId}/{textHash}.wav`, 임시 파일에 쓴 뒤 옮김
- `Optional<byte[]> read(String key)`, `void delete(String key)`, `void deleteStep(String stepId)`. 저장 폴더 밖이면 거부
- `SupertonicTtsClient#synthesize(String text) -> byte[]`. 실패하면 `RuntimeException`. 주소는 `local-llm.base-url` + `/api/flask/tts`, 헤더 `X-API-Key`, 연결 3초, 읽기 30초
- `SupertonicTtsClient#isAvailable() -> boolean` (키가 있을 때만 true)

- [ ] 시험: 저장 후 읽으면 같은 바이트. `../` 열쇠는 비어 있음. `deleteStep`은 그 폴더만 지움.

### Task 3: 대기열과 채우기

**Files:**
- Create: `routine/application/service/RoutineStepSpeechFiller.java`, `RoutineStepSpeechQueue.java`
- Modify: `RoutineStepRepository.java`: `updateSpeechPath(stepId, path)`, `clearSpeechPath(stepId)`
- Test: `RoutineStepSpeechFillerTest.java`, `RoutineStepSpeechQueueTest.java`

**Interfaces — Produces:**
- `RoutineStepSpeechQueue#enqueueAfterCommit(String stepId)`: 트랜잭션이 없으면 즉시 넣음
- `RoutineStepSpeechQueue#enqueue(String stepId)`: 대기 중이면 무시. 단일 스레드
- `RoutineStepSpeechFiller#fill(String stepId)`: 던지지 않음

`fill` 순서: 단계 읽기(없으면 끝) > 언어 확인(ko 아니면 끝) > 문장·해시 > 합성 > 저장 > 단계 다시 읽어 해시 비교(다르면 파일 지우고 끝) > `updateSpeechPath` 0행이면 파일 지움.

- [ ] 시험: 정상 경로에서 경로 갱신 / 합성 예외에도 던지지 않고 갱신 없음 / 생성 중 글이 바뀌면 파일 삭제 / 단계 없음이면 합성 안 함 / 언어 en이면 합성 안 함 / 같은 stepId를 두 번 넣어도 1번 처리.

### Task 4: 예약 지점, 주기 작업, 내려받기 API

**Files:**
- Create: `routine/application/service/RoutineStepSpeechSweeper.java`
- Modify: `RoutineCreationWriter.save`, `RoutineService.updateStep/addStep/duplicate/deleteStep/delete`, `RoutineQueryService` (`getStepSpeech`), `RoutineController` (`GET /{routineId}/steps/{stepId}/speech`), `RoutineStepRepository` (주기 작업 조회)
- Test: `RoutineStepSpeechSweeperTest.java`, 기존 `RoutineService` 시험에 예약 확인 추가

- [ ] 글 수정: 문장이 바뀌면 `speechPath=null` 후 예약. 순서만 바꾸면 예약하지 않음.
- [ ] 삭제: 커밋 뒤 `deleteStep(stepId)`.
- [ ] 주기 작업: 2분마다, `speechPath is null`이고 일과 언어가 ko나 null인 단계 20건. `tts` 사용 불가면 아무것도 하지 않음.
- [ ] API: 응답 `audio/wav`, 헤더 `X-Speech-Key`. 없으면 404.
- [ ] `./gradlew test` 전체 통과.

### Task 5: 앱 모델

- Modify: `client/lib/shared/models/action_card.dart`: `String? speechPath`와 `fromJson`/`toJson`. freezed를 다시 생성한다.
- [ ] 시험: `speechPath`가 없거나 숫자여도 죽지 않음.

### Task 6: 앱 음성 캐시·저장소

**Files:**
- Create: `client/lib/features/child/data/card_speech_repository.dart`
- Test: `client/test/card_speech_repository_test.dart`

**Interfaces — Produces:**
- `CardSpeechRepository#fileFor({routineId, stepId, speechPath}) -> Future<File?>`: 캐시가 있으면 그 파일, 없으면 받아 저장. WAV 머리(`RIFF....WAVE`)가 아니면 null. 같은 열쇠의 동시 요청은 하나로 합침. 저장할 때 같은 stepId 폴더의 다른 파일을 지움
- `CardSpeechRepository#syncRoutine(routineId, cards)`: `speechPath` null 카드의 폴더 삭제, 나머지는 차례로 미리 받기(동시 1건)
- 용량 상한 60MB, 오래 안 쓴 것부터 삭제
- 위치: `{appSupport}/card_images/speech/{stepId}/{sha256(speechPath)}.wav`

- [ ] 시험: 두 번 요청해도 GET 1번 / 새 열쇠를 저장하면 옛 파일 삭제 / WAV 아니면 저장 안 함 / null 카드 폴더 삭제 / 상한 넘으면 오래된 것 삭제.

### Task 7: 재생 순서와 호출부

- Modify: `speech_service.dart`: `StoredSpeechSource`, `StoredSpeech`. `SpeechService.speak(text, {language, stored})`. provider는 안드로이드면 `stored > device > remote`, 아니면 `device > remote`
- Modify: 호출부 3곳에서 `stored:`를 넘김. 이룸이 일과 화면과 카드확인 화면 진입 시 `syncRoutine` 호출
- Test: `speech_service_test.dart`
- [ ] 시험: 안드로이드는 저장 음성이 성공하면 기기를 부르지 않음 / 저장 실패면 기기 / 아이폰은 저장 음성을 부르지 않음 / stop은 셋 다 멈춤.
- [ ] `flutter test`와 `flutter analyze` 0건.

### Task 8: 실제 확인

- [ ] 로컬 서버와 안드로이드 에뮬레이터로 일과 생성 > 서버 로그 `[routine speech] saved` > 앱 재생 > 다시 누르면 GET 없이 재생 > 글 수정 > 새 음성 재생.
