# Free / Pro 라이선스 · 권한 뼈대

> 이슈: https://github.com/Twin-Fang/elum/issues/158

> 관련 설계: [이미지 프로바이더 추상화](./2026-09-18-image-provider-abstraction-design.md) ·
> [Free 픽토그램](./2026-09-18-free-pictogram-design.md) ·
> [관리자 화면 개편](./2026-09-18-admin-console-revamp-design.md)

## 배경

라이선스·구독·결제 코드가 **하나도 없다**
(`licen|subscri|billing|payment|purchase|receipt|entitle` 전수 검색 0건).

요금제 정책(가격, 한도 숫자)은 아직 정해지지 않았다. 그래도 뼈대를 먼저 넣는 이유는,
정책이 정해졌을 때 **코드를 갈아엎지 않기 위해서**다. 그러려면 정책이 코드가 아니라
**데이터**여야 한다.

`SystemConfig`가 이미 그 역할을 한다 — `ConfigKey`에 키를 추가하면 기본값이 시딩되고
관리자 화면에 자동으로 뜨며 30초 안에 전 인스턴스에 반영된다. **다만 전역 설정이라
회원별 구독 상태는 담지 못한다.** 그 한 조각만 새로 만든다.

## 확정된 정책 (2026-09-18 결정)

| | Free | Pro |
| --- | --- | --- |
| 카드 글 생성 (LLM) | **가능** · 주 N회 | 가능 · 무제한 |
| 카드 그림 | **픽토그램** (Mulberry, 원가 0) | **AI 맞춤 삽화** (이룸이 캐릭터 등장) |
| 광고 (AdMob) | 표시 | 제거 |
| 이룸이 명수 | 1명 | 여러 명 |
| 기록 보관 | N일 | 무제한 |

**왜 이렇게 갈랐나.** 비용의 99%가 이미지다 — 이미지 포함 일과 하나가 약 550원인데
텍스트만이면 약 4원이다(137배). Free에서 이미지만 빼면 원가가 거의 사라지고
**AdMob 수익이 그 원가를 넘는다.** Free가 흑자 구조가 된다.

그리고 Pro의 가치가 선명해진다. *"우리 이룸이가 그림에 나와요"* 는 픽토그램이
절대 못 주는 것이다.

**한도 숫자는 아직 정하지 않는다.** 원가가 프로바이더 선택에 따라 8배 달라지므로
([프로바이더 설계](./2026-09-18-image-provider-abstraction-design.md)) 그 작업이 끝난
뒤 실측 원가 위에서 정한다. 그때까지는 무제한(-1)으로 시딩해 **지금 동작이 지금과
똑같게** 둔다.

집계 기간은 **주 단위**(월요일 00:00 Asia/Seoul 시작)로 한다.

## 목표 / 비목표

**목표**

1. 회원의 플랜·구독 상태를 표현한다.
2. 한도·권한을 관리자 화면에서 배포 없이 바꾼다.
3. 기능 코드가 **단 하나의 통로**로만 권한을 묻게 한다.
4. 결제가 없는 지금도 관리자가 Pro를 **수동 발급**해 데모·베타가 돌아간다.
5. 나중에 결제를 붙일 때 기존 코드를 고치지 않는다.

**비목표** (이번에 하지 않는다)

- **실제 결제 연동.** 애플/구글 인앱결제냐 자체 PG냐가 미정이다. 영수증 검증 서버는
  별도 작업이다. 이번에는 **붙일 자리만** 만든다.
- **플랜 3개 이상, 기관별 커스텀 한도.** 지금 필요 없다. 아래 "확장 경로" 참조.
- 클라이언트 AdMob 연동. `ADS_REMOVED` 권한만 정의하고 실제 광고는 클라 작업이다.

## 접근법 선택

| | 구조 | 정책 변경 | 판정 |
| --- | --- | --- | --- |
| A. 플랜·권한 테이블 3개 | `plan`, `plan_entitlement`, `subscription` | DB 행 수정 | 가장 유연. **지금은 과함** |
| **B. SystemConfig 재사용 + 구독 테이블 1개** | 한도는 `ConfigKey`, 상태만 신규 테이블 | 관리자 화면에서 바로 | **채택** |
| C. Member에 plan 컬럼 | 컬럼 1개 | 배포 필요 | 만료·이력 표현 불가. 탈락 |

**B를 고른 이유** — 기존 설정 패턴을 그대로 쓰므로 관리자 화면·캐시·기본값 폴백이
공짜로 따라온다. 테이블은 하나만 는다.

### 확장 경로 — B에서 A로 가는 길을 막지 않는다

핵심은 **한도를 읽는 통로를 하나로 좁히는 것**이다.

```java
entitlementService.requireAllowed(memberId, Entitlement.AI_IMAGE_GENERATION);
```

호출부는 내부가 `SystemConfig`인지 테이블인지 모른다. 플랜이 셋 이상 되거나 기관별
커스텀 한도가 필요해지면 **`EntitlementService` 구현만 갈아끼운다.** 호출부는 한 줄도
안 바뀐다.

## 설계

### 구독을 Member에 붙인다 (Profile 아님)

`Profile`이 `Member`와 N:1이라 어디에 붙일지 갈린다. **`Member`에 붙인다.**

- 결제 주체가 보호자다. `Profile`은 로그인하지 않으므로 결제할 수 없다.
- 인앱결제는 Apple ID / Google 계정에 묶인다. 프로필 단위 구독은 스토어가 모른다.
- 기관이 이룸이 여러 명을 지원하는 경우는 **`PROFILE_MAX_COUNT` 권한으로 표현**된다.
  구독을 프로필마다 둘 필요가 없다.

### 엔티티

```java
/// 계정의 구독 상태. 행이 없으면 FREE로 간주한다 — 기존 회원 마이그레이션이 필요 없다.
@Entity
public class Subscription extends BaseEntity {

  @Id @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @OneToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "member_id", nullable = false, unique = true)
  private Member member;

  @Enumerated(EnumType.STRING) @Column(nullable = false)
  private PlanType plan;              // FREE, PRO

  @Enumerated(EnumType.STRING) @Column(nullable = false)
  private SubscriptionStatus status;  // ACTIVE, EXPIRED, CANCELLED

  private LocalDateTime startedAt;

  /// null이면 무기한. 관리자 수동 발급이나 FREE가 여기 해당한다.
  private LocalDateTime expiresAt;

  /// 이 구독이 **어떻게** 생겼는가. 결제를 붙일 자리다.
  @Enumerated(EnumType.STRING) @Column(nullable = false)
  private SubscriptionSource source;  // MANUAL, APPLE_IAP, GOOGLE_IAP, PROMO

  /// 스토어 구독 ID·영수증 식별자. 지금은 항상 null이다.
  private String externalRef;

  /// 수동 발급 사유. 누가 왜 켰는지 남기지 않으면 나중에 추적할 수 없다.
  private String memo;
}
```

**`source`와 `externalRef`가 결제를 붙이는 이음새다.** 나중에 인앱결제를 연동하면
영수증 검증 서비스가 `source=APPLE_IAP`, `externalRef=<구독ID>`로 행을 쓰고,
`EntitlementService`는 **아무것도 바뀌지 않는다.**

### 권한 정의

```java
public enum Entitlement {
  // 켜짐/꺼짐
  AI_IMAGE_GENERATION(Kind.FLAG),     // AI 맞춤 삽화
  ADS_REMOVED(Kind.FLAG),             // 광고 제거

  // 수치 한도 (-1 = 무제한)
  ROUTINE_CREATE_PER_WEEK(Kind.LIMIT),
  ROUTINE_MAX_COUNT(Kind.LIMIT),
  PROFILE_MAX_COUNT(Kind.LIMIT),
  HISTORY_RETENTION_DAYS(Kind.LIMIT);

  public enum Kind { FLAG, LIMIT }
}
```

### 단일 통로

```java
public interface EntitlementService {

  boolean isAllowed(String memberId, Entitlement flag);

  /// -1이면 무제한.
  int limitOf(String memberId, Entitlement limit);

  /// 불허면 CustomException. 호출부가 if를 쓰지 않게 한다.
  void requireAllowed(String memberId, Entitlement flag);

  /// current가 한도 이상이면 CustomException.
  void requireWithinLimit(String memberId, Entitlement limit, int current);

  /// 클라이언트에 한 번에 내려줄 현재 권한 스냅샷.
  EntitlementSnapshot snapshot(String memberId);
}
```

`EntitlementSnapshot`은 `GET /api/member/me` 응답에 실어 보낸다. 클라이언트가 화면마다
권한을 따로 묻지 않게 하기 위해서다.

### 설정 키 — 플랜 × 권한

`ConfigGroup`에 `PLAN_FREE`, `PLAN_PRO`를 추가하고 권한마다 키를 둔다.

| 키 | 타입 | 초기값 | 나중에 |
| --- | --- | --- | --- |
| `FREE_AI_IMAGE_GENERATION` | BOOLEAN | `false` | — |
| `PRO_AI_IMAGE_GENERATION` | BOOLEAN | `true` | — |
| `FREE_ADS_REMOVED` | BOOLEAN | `false` | — |
| `PRO_ADS_REMOVED` | BOOLEAN | `true` | — |
| `FREE_ROUTINE_CREATE_PER_WEEK` | INTEGER | `-1` (무제한) | 원가 확정 후 |
| `PRO_ROUTINE_CREATE_PER_WEEK` | INTEGER | `-1` | — |
| `FREE_ROUTINE_MAX_COUNT` | INTEGER | `-1` | 원가 확정 후 |
| `PRO_ROUTINE_MAX_COUNT` | INTEGER | `-1` | — |
| `FREE_PROFILE_MAX_COUNT` | INTEGER | `-1` | `1` |
| `PRO_PROFILE_MAX_COUNT` | INTEGER | `-1` | — |
| `FREE_HISTORY_RETENTION_DAYS` | INTEGER | `-1` | 추후 |
| `PRO_HISTORY_RETENTION_DAYS` | INTEGER | `-1` | — |

**켜짐/꺼짐만 플랜차를 두고 수치 한도는 전부 무제한(-1)으로 두는 이유** — 구조만 넣고
지금 동작은 지금과 똑같게 유지하기 위해서다. 해커톤 심사·데모 중에 한도 때문에 막히는
사고가 나면 안 된다. 숫자는 관리자 화면에서 나중에 채운다.

> ⚠️ `ConfigValueType`에 **BOOLEAN이 없다**(STRING/INTEGER/DECIMAL/SELECT).
> 켜짐/꺼짐 권한을 담으려면 `BOOLEAN`을 추가하고 관리자 화면에 토글 위젯을 더한다.
> 이 변경은 [관리자 화면 개편](./2026-09-18-admin-console-revamp-design.md)과 겹친다.

### 주간 사용량 집계 — 새 테이블을 만들지 않는다

`AiCallLog`에 이미 목적에 맞는 인덱스가 있다.

```java
// AiCallLog.java 주석 — "회원별 사용량 집계와 관리자 모니터링의 원천 데이터다"
@Index(name = "idx_ai_call_log_member_created", columnList = "member_id, created_at")
```

```java
// 이번 주 일과 생성 횟수 = 일과 생성용 텍스트 호출 건수
int used = aiCallLogRepository.countByMemberIdAndCallTypeAndCreatedAtGreaterThanEqual(
    memberId, AiCallType.GEMINI_TEXT_CREATE, weekStart());

// 월요일 00:00 Asia/Seoul
private LocalDateTime weekStart() { ... }
```

**`Routine` 테이블을 세지 않는 이유** — 일과를 지우면 행이 사라져 *만들고 지우고 다시
만들기*로 우회된다. AI 비용은 만드는 순간 나가고 지워도 돌아오지 않는다.
`AiCallLog`는 지워지지 않으므로 실제로 쓴 돈을 센다.

### 권한 검사 지점

| 검사 | 위치 | 실패 시 |
| --- | --- | --- |
| `ROUTINE_CREATE_PER_WEEK` | `RoutineService` 생성 진입부 (`RoutineRequestCooldownGuard` 옆) | 거부 + 에러 코드 |
| `AI_IMAGE_GENERATION` | `RoutineAiPipeline` 이미지 단계 앞 | **거부하지 않고** 픽토그램 경로로 ([③ 참조](./2026-09-18-free-pictogram-design.md)) |
| `ROUTINE_MAX_COUNT` | 같은 생성 진입부 | 거부 + 에러 코드 |
| `PROFILE_MAX_COUNT` | 프로필 생성 API | 거부 + 에러 코드 |

**이미지 권한만 거부가 아니라 분기다.** Free도 카드를 만들 수 있어야 하고, 그림이
픽토그램으로 바뀔 뿐이다.

### 관리자 수동 발급

회원 상세 화면(`member-detail.html`)에 구독 섹션을 더한다.

- 현재 플랜·상태·만료일·발급 경로 표시
- **Pro 발급** (기간 선택 + 사유 필수 입력 → `source=MANUAL`, `memo` 저장)
- **회수** (`status=CANCELLED`)

사유를 필수로 받는 이유는, 나중에 "이 계정은 왜 Pro지"를 답할 수 있어야 하기 때문이다.

## 행복 경로

```
회원이 일과를 만든다
  → EntitlementService.requireWithinLimit(ROUTINE_CREATE_PER_WEEK, 이번주사용량)
  → 통과
  → 카드 글 생성 (LLM)
  → isAllowed(AI_IMAGE_GENERATION)?
      Pro  → AI 맞춤 삽화
      Free → 픽토그램 검색
  → 카드 완성
```

## 실패 경로

| 상황 | 동작 | 근거 |
| --- | --- | --- |
| `Subscription` 행 없음 | **FREE로 간주** | 기존 회원 전부 해당. 마이그레이션 불필요 |
| `expiresAt < now` | FREE로 간주 | 조회 시점 계산. 만료 배치가 필요 없다 |
| 사용량 집계 쿼리 실패 | **허용**하고 에러 로그 | 우리 DB 문제로 사용자가 못 쓰면 안 된다. 원가가 일시적으로 새는 쪽이 낫다 |
| 설정값 파싱 실패 | 기본값 폴백 | `SystemConfigService` 기존 동작 |
| 한도 초과 | 거부 + 에러 코드 | 아래 문구 참조 |
| Pro인데 이미지 생성 실패 | 이미지 없이 카드 생성 | [① 실패 경로](./2026-09-18-image-provider-abstraction-design.md) 유지 |

### 에러 코드 추가

```java
// ENTITLEMENT
ROUTINE_CREATE_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN, "이번 주에 만들 수 있는 일과를 다 썼어요."),
ROUTINE_COUNT_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN, "일과를 더 만들려면 기존 일과를 정리해주세요."),
PROFILE_COUNT_LIMIT_EXCEEDED(HttpStatus.FORBIDDEN, "이룸이를 더 추가할 수 없어요."),
```

문구는 **해요체·능동형**이다 (CLAUDE.md 용어 규칙). "제한을 초과하였습니다" 같은
문어체를 쓰지 않고, **"아이"라는 말도 쓰지 않는다.**

## 테스트

- `EntitlementService` — 구독 없음 → FREE / 만료 → FREE / Pro 활성 / -1 무제한 처리
- 주간 집계 — 주 경계(월요일 00:00 KST) 앞뒤, 집계 실패 시 허용 폴백
- 일과 생성 — 한도 초과 거부, 한도 내 통과
- 이미지 분기 — Free가 픽토그램 경로로 가는지
- 관리자 수동 발급 — 사유 없이 발급 거부

## 열린 질문

1. **한도 숫자.** 프로바이더 작업으로 실측 원가가 나온 뒤 정한다.
2. **결제 경로.** 애플/구글 인앱결제가 유력하지만(앱 내 디지털 재화) 확정 전이다.
   `source` enum에 자리만 있다.
3. **기관(B2B) 판매 형태.** 이룸이 여러 명을 계정 하나로 볼지, 기관 계정을 따로 둘지.
   지금 구조는 전자를 지원한다.
