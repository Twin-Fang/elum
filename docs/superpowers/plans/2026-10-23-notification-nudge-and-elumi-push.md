# 알림 다시 권하기 + 이룸이 기기 알림 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 알림 꺼진 보호자·이룸이 기기에 7일마다 알림 켜기를 권하고, 이룸이 기기에 "새 일과가 도착했어요" 푸시를 보낸다.

**Architecture:** 서버 `push_device` 에 `link_id` 를 더해 보호자/이룸이 기기를 가른다. 보호자 발송은 `link_id is null` 만, 이룸이 발송은 살아 있는 연결의 `link_id` 만 본다. 클라는 권한 다시 권하기를 한 클래스(`PushPermissionNudge`)로 두고 보호자 홈(공지 런처 뒤)·이룸이 홈(업데이트 권유 런처 뒤)에서 부른다.

**Tech Stack:** Spring Boot·JPA·Flyway·FCM Admin SDK / Flutter·Riverpod·firebase_messaging·flutter_local_notifications

**Spec:** `docs/superpowers/specs/2026-10-23-notification-nudge-and-elumi-push-design.md` (이슈 #991)

## Global Constraints

- 다시 권하는 간격 7일. 한 번도 안 물은 기기는 바로.
- 이룸이 기기에 보호자 알림 7종 금지.
- 이룸이 푸시 문구에 일과 제목 금지. ko `새 일과가 도착했어요`.
- 다른 도메인 repository 직접 사용 금지 (`cross-domain-repository-allowlist.txt` 는 늘릴 수 없음) — 서비스 경유.
- 기존 API 응답·저장 키·에러 코드 불변. 옛 앱 동작 불변.
- 용어: 아이 금지, 해요체. 앱 테스트 없음(#848) — `flutter analyze`·`client/tool/check_*`.

## Review Focus

1. 같은 회원 ID 를 쓰는 이룸이 기기가 보호자 알림을 받는 경우 — 보호자 발송은 `link_id is null` 만 (Task 1 테스트).
2. 끊긴 연결의 남은 토큰 — 발송 시 살아 있는 연결만 대상 (Task 2 테스트).
3. 이룸이 기기의 해제 요청이 보호자 토큰을 지우는 경우 — 해제는 `link_id` 일치 필요 (Task 1 테스트).
4. 공지 팝업·업데이트 권유와 시트가 겹쳐 뜸 — 공지가 하나라도 떴으면 그 실행엔 안 띄움 (Task 4).
5. 종료 상태에서 푸시를 눌렀는데 일과가 없어짐 — 이룸이 홈에 머묾 (Task 5).

---

### Task 1: 서버 기기 구분 (`link_id`)

**Files:**
- Create: `server/src/main/resources/db/migration/V57__add_push_device_link_id.sql` (번호는 커밋 직전 develop 최신 확인)
- Modify: `notification/infrastructure/entity/PushDevice.java`, `notification/infrastructure/repository/PushDeviceRepository.java`, `notification/application/service/PushDeviceService.java`, `notification/application/controller/PushDeviceController.java`, `notification/application/service/PushDispatcher.java:75`, `common/infrastructure/config/SecurityConfig.java:165` 앞
- Test: `PushDeviceServiceTest`, `PushDispatcherTest`, `NotificationSecurityTest`

**Interfaces:**
- Produces: `PushDevice.linkId` (String, nullable) · `PushDeviceRepository.findAllByMemberIdAndLinkIdIsNull(String)` · `findAllByLinkIdIn(Collection<String>)` · `int deleteAllByLinkId(String)` · `PushDeviceService.register(Caller, PushDeviceRegisterRequest)` · `unregister(Caller, String token)` · `int removeLinkDevices(String linkId)`

- [ ] 테스트: 이룸이 호출 등록 → `linkId` 저장 / 보호자 재등록 → `linkId` null 로 / 이룸이 해제가 보호자 행 못 지움 / 발송이 이룸이 기기 제외 / ELUMI 권한 PUT·DELETE 204
- [ ] 구현: 마이그레이션 `alter table push_device add column link_id varchar(255); create index idx_push_device_link_id on push_device(link_id);`
- [ ] `devicesOf` 는 전부 반환 유지 (관리자 상세) — 이룸이 기기 표시는 하지 않음 (범위 밖)

### Task 2: 서버 일과 도착 발송

**Files:**
- Create: `notification/application/service/ElumiPushDispatcher.java`
- Modify: `link/application/service/DeviceLinkService.java` (`liveLinkIdsOf`, `terminate` 에서 `removeLinkDevices`), `notification/application/listener/NotificationEventListener.java` (`onRoutineSent`), `notification/infrastructure/push/PushMessage.java` (`androidChannelId` 추가), `FcmPushSender.java` (채널 지정), `PushMessageFactory.java`, `i18n/push-messages_{ko,en,ja,zh,es}.properties`
- Test: `ElumiPushDispatcherTest`, `FcmPushSenderTest`, `DeviceLinkServiceTest`

**Interfaces:**
- Consumes: Task 1 repository
- Produces: `DeviceLinkService.liveLinkIdsOf(String profileId) -> List<String>` (revokedAt null + redeemedAt not null) · `ElumiPushDispatcher.dispatchRoutineArrived(String profileId, String routineId)` · data `type=ELUMI_ROUTINE_ARRIVED`, `routineId`, `profileId` · Android 채널 `elumi_routines` · collapseKey `elumi-routine-{routineId}` · 문구 키 `push.elumi_routine_arrived`

- [ ] 테스트: 살아 있는 연결 기기만 발송 / 무효 토큰 삭제 / 대상 없으면 발송 0 / 채널 id 가 Android 알림에 실림
- [ ] 리스너: 기존 보호자 기록 뒤 별도 try 로 이룸이 발송 (한쪽 실패가 다른 쪽을 막지 않음)

### Task 3: 클라 이룸이 토큰 등록

**Files:** `features/notification/application/push_token_registrar.dart` (`_canRegister` 의 이룸이 차단 제거)
- 이룸이 기기 연결 끊김·로그아웃은 기존 `unregisterBeforeSignOut` 경로 확인

### Task 4: 클라 다시 권하기

**Files:**
- Create: `features/notification/application/push_permission_nudge.dart`
- Modify: `core/storage/local_storage.dart`·`shared_prefs_storage.dart`·`in_memory_storage.dart` (`pushPermissionNudgedAt`), `features/notification/application/push_permission_prompt.dart` (`maybeAsk` 가 시각 기록), `core/widgets/push_permission_sheet.dart` (문구 인자), `features/notice/presentation/guardian_notice_launcher.dart`, `core/app_status/update_suggestion_launcher.dart`, `l10n/app_*.arb`

**Interfaces:**
- Produces: `PushPermissionNudge.maybeNudge(BuildContext) -> Future<void>` · `nudgeIntervalDays = 7` · `LocalStorage.pushPermissionNudgedAt (DateTime?)`
- 규칙: 권한 허용이면 끝 / 보호자 기기에서 이룸이 화면이면 안 띄움 / 마지막 권함+7일 이내면 안 띄움 / 시트 → 허용이면 `DeviceNotificationPermissionController.turnOn` 과 같은 경로(안 물었으면 시스템 창, 아니면 기기 설정) → 등록 동기화

### Task 5: 클라 이룸이 푸시 수신·탭

**Files:** `features/notification/application/push_message_router.dart`, `app.dart` (`_contextIfInElumiArea`), `features/notification/domain` 의 종류 enum 은 건드리지 않음 (이룸이 종류는 라우터에서 문자열 상수로 판정)
- 이룸이 기기 전경 수신 `ELUMI_ROUTINE_ARRIVED` → 일과 목록 새로 받기
- 탭 → 이룸이 화면 준비 대기 → 목록 새로 받기 → `routineId` 찾으면 `Routes.childRoutineDetail` push(extra), 없으면 머묾
- Android 채널 `elumi_routines` 생성 (이름 l10n `pushChannelElumiRoutines`)

### Task 6: 검증
- [ ] `./gradlew compileJava compileTestJava` + `--tests` 로 위 테스트만
- [ ] `flutter analyze`, `client/tool/check_*`
- [ ] 배포 후 시뮬레이터 2대 E2E
