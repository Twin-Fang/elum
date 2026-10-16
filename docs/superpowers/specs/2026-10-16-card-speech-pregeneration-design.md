# 카드 음성 미리 만들기 설계 (#675)

## 배경

- 안드로이드 기기 음성이 쉬고 높낮이가 흔들려 유령 목소리처럼 들린다. 기종마다 엔진과 목소리 데이터가 달라 앱이 통제할 수 없다.
- 서버 음성(AI 서버 Supertonic, `F1`)은 목소리가 일정하다. 다만 2026-10-16 실측으로 보면 매번 부르기에는 느리다.

| 조건 | 결과 |
|---|---|
| 한 건 (6·25·45자) | 2.3~3.5초, WAV 135·387·633KB |
| 동시 5건 | 전부 성공, 가장 늦은 건 7.5초 |
| 동시 20건 | 전부 성공, 가장 늦은 건 25.7초 |

  AI 서버는 요청을 하나씩 처리하므로, 동시에 보내면 대기만 쌓인다.
- AI 서버가 꺼지면 바로 실패한다. 같은 날 Docker Desktop이 내려가 `503`이 나고 있었는데, 아무도 모르고 있었다.

## 목표

- 이룸이가 스피커를 누르면 **기다리지 않고**, **기종과 상관없이 같은 목소리**가 나온다.
- 재생할 때 AI 서버 상태와 상관없이 소리가 난다.
- AI 서버에는 카드 1장당 1번만 요청한다. 동시에 1건 넘게 보내지 않는다.

## 하지 않는 것

- `ko` 밖의 언어 음성. 그 언어는 기기 음성으로 읽는다.
- 목소리 고르기 UI. `F1`으로 고정한다.
- WAV 압축이나 형식 변환.
- 아이폰 재생 순서 변경. 아이폰은 지금 그대로 둔다.
- 앱 안에 엔진 내장(B안). 별도 시험으로 진행한다.

## 전체 흐름

```mermaid
flowchart LR
  A[일과 생성 / 단계 수정 / 단계 추가] -->|커밋 후 예약| Q[음성 대기열 - 한 번에 1건]
  S[주기 작업: 음성 없는 ko 단계] --> Q
  Q -->|POST /api/flask/tts supertonic F1| T[AI 서버]
  T -->|WAV| ST[단계 음성 저장소 - 로컬 디스크]
  ST -->|speech_path 갱신| DB[(routine_step)]
  APP[앱] -->|GET .../steps/{stepId}/speech| ST
```

## 서버

### 읽을 문장 (단일 원본)

앱은 지금 `'${displayTitle}. ${description}'`을 읽는다(`displayTitle`은 제목이 비면 설명이다). 서버는 같은 규칙으로 문장을 만드는 `RoutineStepSpeechText.of(title, description)` 하나만 둔다.

이제 앱은 저장된 음성이 있으면 그 파일을 재생한다. 그래서 문장 규칙이 앞으로 서로 어긋나도 소리가 틀어지지는 않는다.

### 저장 열쇠와 낡은 음성 판정

- 열쇠 형식: `{stepId}/{문장 SHA-256 앞 16자}.wav`. 문장이 바뀌면 열쇠도 바뀐다. 앱 캐시도 열쇠를 해시해 저장하므로 옛 파일과 새 파일이 섞이지 않는다.
- 단계 글을 고치면 `speech_path`를 `null`로 비우고 다시 만들도록 예약한다.
- 생성 중에 글이 또 바뀔 수 있다. 저장 직전에 단계를 다시 읽어, 문장 해시가 다르면 파일을 버린다. 새 글은 이미 다시 예약돼 있다.

### 구성 요소

| 이름 | 위치 | 하는 일 |
|---|---|---|
| `RoutineStepSpeechStorage` (인터페이스) + `LocalFileRoutineStepSpeechStorage` | `routine/infrastructure/storage` | `save(stepId, textHash, wav)`, `read(key)`, `delete(key)`, `deleteStep(stepId)`. 그림 저장소와 같은 구조. 경로 설정은 `routine.speech-storage-path`, 기본값 `data/routine-speech` |
| `SupertonicTtsClient` | `ai/infrastructure/client` | `POST {tts.base-url}/api/flask/tts`, `X-API-Key`, `{text, engine: supertonic, voice: F1}`. 연결 3초, 읽기 30초 |
| `RoutineStepSpeechQueue` | `routine/application/service` | 단일 스레드 실행기. 같은 stepId가 이미 대기 중이면 다시 넣지 않는다. 커밋 후 예약(`afterCommit`) |
| `RoutineStepSpeechFiller` | `routine/application/service` | 1건 처리: 단계 확인 > 문장 생성 > 합성 > 저장 > 해시 재확인 > `speech_path` 갱신. 어떤 실패도 밖으로 던지지 않는다 |
| `RoutineStepSpeechSweeper` | `routine/application/service` | `@Scheduled` 2분마다. `speech_path IS NULL` 이고 일과 언어가 `ko`인 단계를 최대 20건 대기열에 넣는다. 실패분과 기존 일과를 메운다 |

### 설정

```yaml
tts:
  enabled: true             # false 면 예약·주기 작업 모두 끔
  base-url: https://ai.suhsaechan.kr
  api-key: ${TTS_API_KEY}   # 앱의 ELUM_TTS_API_KEY 와 같은 키
routine:
  speech-storage-path: data/routine-speech
```

`tts.api-key`가 비어 있으면 기능을 끄고 경고 로그를 한 번 남긴다. 그러면 앱은 지금처럼 기기 음성으로 읽는다. 운영 반영 시 서버 배포 Secret(`application-prod.yml`)에 키를 넣어야 한다.

### 예약 지점

| 지점 | 동작 |
|---|---|
| 일과 생성 저장(`RoutineCreationWriter.save`) | 모든 단계 예약 |
| 단계 글 수정(`RoutineService.updateStep`) | 문장이 바뀌었을 때만 `speech_path=null` 후 예약 |
| 단계 추가(`addStep`) | 예약 |
| 일과 복제(`duplicate`) | 원본 `speech_path`를 그대로 복사하지 않고 예약한다. 열쇠가 stepId 폴더에 묶여 있어서다 |
| 단계·일과 삭제 | 그림을 지우는 자리에서 음성도 지운다 |

### 내려받기 API

- `GET /api/routines/{routineId}/steps/{stepId}/speech` → `audio/wav`. 인증과 권한은 그림 GET과 같다. `speech_path`가 `null`이면 `404`.
- 단계 응답(`RoutineStepResponse`와 이룸이 쪽 응답)에 `speechPath`(nullable)를 추가한다.

### DB

`V37__add_routine_step_speech_path.sql`: `routine_step.speech_path VARCHAR(255) NULL`.

### 실패 경로

| 상황 | 결과 |
|---|---|
| AI 서버 꺼짐, 503, 타임아웃 | `speech_path`는 `null`로 남는다. 2분 뒤 주기 작업이 다시 넣는다. 앱은 기기 음성으로 읽는다 |
| 키 없음 | 기능 꺼짐. 앱은 기기 음성 |
| 생성 중 단계 삭제 | 저장하지 않는다. 이미 저장했으면 파일을 지운다 |
| 생성 중 글 수정 | 해시가 다르면 파일을 버린다. 새 예약이 처리한다 |
| 대기열 적체 | 같은 stepId는 한 번만 들어간다. 주기 작업은 한 번에 최대 20건 |

로그 접두사는 `[routine speech]`로 고정한다. 실패 로그에는 상태 코드와 원인을 남긴다.

## 앱

### 재생 순서

| 플랫폼 | 순서 |
|---|---|
| 안드로이드 | 저장 음성 > 기기 음성(Google 엔진, #615) > 실시간 서버 음성 |
| 아이폰 | 기기 음성 > 실시간 서버 음성 (지금 그대로) |

- 저장 음성은 `speechPath`가 있고 일과 언어가 `ko`일 때만 쓴다. 받지 못하면 다음 순서로 넘어간다.
- 정지할 때는 세 가지 모두 멈춘다.

### 구성 요소

| 이름 | 하는 일 |
|---|---|
| `ActionCard.speechPath` | 서버 응답의 `speechPath` |
| `CardSpeechRepository` | GET으로 WAV를 받는다. 같은 열쇠의 동시 요청은 하나로 합친다. 디스크 캐시 이름은 열쇠 해시이고, 로그아웃 때 지운다. `card_image_repository`·`card_image_disk_cache`와 같은 구조 |
| `StoredSpeech` | 캐시 파일을 `AudioPlayer`(`DeviceFileSource`)로 재생 |
| `SpeechService.speak(text, {language, stored})` | `stored`는 `StoredSpeechSource(routineId, stepId, speechPath)`이고 nullable. 호출부 3곳(카드확인, 단계 뷰어, 이룸이 일과)이 넘긴다 |
| 미리 받기 | 이룸이 일과 화면과 카드확인 화면에 들어가면 `speechPath`가 있는 카드를 차례로 받아 둔다(동시 1건). 실패해도 조용히 기록만 남긴다 |

### 실패 경로

받기 실패, 파일 손상, 재생 실패는 모두 다음 순서로 넘어간다. 마지막까지 실패하면 지금처럼 `E-TTS`를 보여 준다.

## 시험

| 시험 | 깨지면 생기는 사용자 문제 |
|---|---|
| 서버: 글 수정 시 `speech_path`를 비우고 다시 예약 | 고친 문장 대신 옛 문장이 읽힌다 |
| 서버: 생성 중 글이 바뀌면 파일을 버림 | 옛 문장이 새 카드에 붙는다 |
| 서버: 같은 stepId는 대기열에 한 번만 | AI 서버에 중복 요청이 쌓인다 |
| 서버: AI 실패해도 예외가 밖으로 안 나가고 `null` 유지 | 일과 저장이 실패한다 |
| 서버: 주기 작업이 `ko`의 `null`만 고르고 20건 제한 | AI 서버가 한꺼번에 몰린다 / 다른 언어를 한국어 목소리로 읽는다 |
| 서버: 문장 규칙(제목 비면 설명) | 설명이 두 번 읽히거나 제목이 빠진다 |
| 앱: 안드로이드는 저장 음성 먼저, 실패 시 기기 | 유령 목소리가 그대로 나온다 / 소리가 안 난다 |
| 앱: 아이폰은 순서 그대로 | 잘 되던 아이폰이 바뀐다 |
| 앱: 같은 열쇠는 한 번만 받고, 다시 누르면 캐시에서 | 누를 때마다 내려받는다 |

마지막에 안드로이드 에뮬레이터에서 일과를 만들고, 저장 음성이 재생되는지 확인한다.

## 배포 시 확인

- 서버 배포 Secret에 `TTS_API_KEY`
- 운영 서버에서 `routine.speech-storage-path`가 볼륨에 마운트돼 있는지(그림 경로와 같은 볼륨인지)
- AI 서버 Docker Desktop 자동 시작. 지금은 시작 스크립트에 없다
