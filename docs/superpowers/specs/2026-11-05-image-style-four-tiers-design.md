# 카드 그림 방식 4가지 + Pro 혜택 목록 (설계)

> 근거 이슈: #1127 (그림 세트 비교) · 관련: #247 (Free 픽토그램), #866 (예시 일과 Lumi), #1081 (Pro 구독)
> 비교 화면: https://claude.ai/artifact/8Lk9yApBaX7d4iSFR2H6bg

## 1. 왜

- 타겟이 2026-10-26부터 **발달장애아동**이다. 지금 Free 카드 그림(Mulberry)은 성인 AAC용 선화라 아이에게 딱딱하다.
- 비교해 보니 Twemoji(이모지)가 아이에게 가장 친근하다. 다만 동작은 못 그리고 물건만 보여 준다.
- 그래서 **Free에서 두 가지(이모지, 기호)를 고르게** 하고, AI가 그리는 두 가지(캐릭터, 실사)는 **Pro**로 둔다. (사용자 결정)
- Free 보호자가 Pro 방식을 누르면 **요금제(결제) 화면**으로 간다. (사용자 결정)
- 요금제 화면은 그림 방식 하나만이 아니라 **Pro 혜택 전체를 나열**해야 한다. (사용자 결정)
  지금 화면에는 혜택이 3줄(크레딧, 워터마크, 인쇄 테마)뿐이다. #1081 이후 생긴 Pro 기능(주간 리포트, 반복 일과 등)이 빠져 있다.

## 2. 목표 / 비목표 / 실패로 보는 것

**목표**

1. 그림 방식이 4개가 된다. 화면 순서는 이모지 > 기호 > 캐릭터(Pro) > 실사(Pro).
2. 이모지 방식 카드에는 Twemoji 그림이 붙는다. 원가는 지금 기호 방식과 같다(AI 그림 0장, 글 호출에 목록만 실음).
3. Free 보호자가 Pro 방식을 누르면 요금제 화면이 열리고, 사서 Pro가 되면 그 방식이 골라진다.
4. 서버도 막는다. Free 계정이 Pro 방식을 저장하려 하면 거절하고, 이미 저장된 Pro 방식은 일과를 만들 때 기호로 바꿔 쓴다(저장값은 지우지 않음).
5. 요금제 화면이 "Pro로 할 수 있는 것"을 전부 나열한다. 그림 방식에서 들어오면 그림 줄이 맨 위다.

**비목표**

- Mulberry 심볼 변형, 비상업 세트(ARASAAC, Sclera) 도입
- Lumi 프리셋 추가 제작 (#1127의 후속 안. 이번 범위 밖)
- 전문가 일과, 예시 일과, 공유 받은 일과의 그림 기호를 이모지로 바꾸기 (계속 Mulberry id 그대로)
- 이미 만든 카드의 그림 기호를 방식 변경에 맞춰 다시 고르기 (새로 만드는 카드부터 적용)
- ja, zh, es 번역 (지금 연 언어는 ko, en뿐)

**실패로 보는 것 (기술적으로 돌아가도)**

- 이모지 방식 카드가 그림 없이 비어 보임
- Free 보호자가 Pro를 눌렀는데 아무 반응이 없거나 살 방법이 없는 잠금만 보임
- 요금제 화면에 실제로는 Free에서도 되는 기능이 Pro 혜택처럼 적힘
- Free로 돌아간 보호자의 일과 만들기가 실패함

## 3. 정한 것

### 3.1 그림 방식 값 (서버·앱 공통 계약)

| 화면 순서 | 서버 enum (apiValue) | 앱 enum | 그림 | 요금제 |
|---|---|---|---|---|
| 1 | `EMOJI` (새로 추가) | `emoji` | Twemoji | Free |
| 2 | `PHOTO_ONLY` (값 유지) | `symbol` (이름 변경, 기존 `photoOnly`) | Mulberry | Free |
| 3 | `CARTOON` (값 유지) | `character` (이름 변경, 기존 `cartoon`) | AI 캐릭터 그림 | Pro |
| 4 | `REALISTIC` (값 유지) | `realistic` | AI 실사 그림 | Pro |

- 서버 enum 값 문자열은 바꾸지 않는다. 옛 앱이 `PHOTO_ONLY`·`CARTOON`을 계속 보내고, DB에도 그 값이 있다. DB 마이그레이션은 필요 없다(`image_style VARCHAR(20)`, CHECK 제약 없음).
- 서버 `ImageStyle`에 질문 메서드를 둔다: `drawsAiImages()` (CARTOON, REALISTIC), `usesEmojiCatalog()` (EMOJI). 지금 `== PHOTO_ONLY`로 분기하는 곳(`RoutineAiPipeline`, `CardImageGenerator`, `RoutineStepEditService`)을 이 메서드로 바꿔 EMOJI도 AI 그림을 건너뛰게 한다.
- 앱 `ImageStyle`도 같은 질문 getter를 둔다: `drawsCardImages`(기존), `isProOnly` (character, realistic).
- 새 이룸이 처음 값(`onboardingDefault`)은 `emoji`. (내 판단: 아동 타겟 첫인상)
- 값을 모를 때 기본값(`fromApiValue` 폴백 = character, 서버 `orDefault` = CARTOON)은 **그대로 둔다**. 서버가 요금제를 보고 실제로 쓸 방식을 정하므로 표시만 어긋나지 않으면 된다.

### 3.2 화면 이름과 설명 (ko)

| 앱 enum | 이름 | 한 줄 설명 |
|---|---|---|
| emoji | 이모지 그림 | 귀여운 이모지로 물건을 보여줘요 |
| symbol | 그림 기호 | 하는 동작을 선 그림으로 보여줘요 |
| character | 캐릭터 그림 | 캐릭터가 직접 해 보여요 |
| realistic | 사진 같은 그림 | 실제 물건처럼 보여요 |

> 이름은 사용자가 확정했다(2026-11-05). en은 같은 뜻으로 옮긴다: Emoji / Picture symbols / Character / Realistic.

- 고르는 카드의 예시 그림은 같은 장면(이 닦기)으로 맞춘다: 이모지 `emoji_toothbrush`, 기호 `brush_teeth_,_to`, 캐릭터 고른 캐릭터, 실사 기존 `image_style_realistic.png`.
- Pro 항목에는 `Pro` 배지(`ElumLabelChip`, 카드 내보내기 Pro 테마와 같은 모양, 키 `cardExportProBadge` 재사용 대신 공용 키 `planProBadge`를 새로 둔다)를 붙인다.

### 3.3 Free / Pro 판정

- 권한 키는 기존 `Entitlement.AI_IMAGE_GENERATION`(플래그)을 쓴다. 새 권한을 만들지 않는다.
- 앱 `PlanAccess`에 `canUseAiImageStyles`를 더한다(원본 `entitlements.aiImageGeneration`). `PlanAccess.free/pro`, `withCanPurchasePro`, `_readPlanAccess`, `member_repository` 파싱, 개발자 도구 요금제 흉내까지 함께 고친다.
- `ConfigKey.FREE_AI_IMAGE_GENERATION` 코드 기본값을 `false`로 내리고 "픽토그램 적용 전까지 켜 둔다" 주석을 지운다.
  - ⚠️ **운영 DB 설정값은 코드 기본값으로 바뀌지 않는다.** 운영에서 실제로 잠그려면 관리자 화면에서 Free 값을 끄는 작업이 따로 필요하다(§6-2: 배포하는 날). 코드 작업은 하지 않는다.

### 3.4 Free가 Pro 방식을 눌렀을 때 (앱)

그림 방식을 고르는 화면 3곳이 모두 같은 규칙을 따른다: 온보딩(`image_style_screen.dart`), 보호자 설정(`image_style_settings_screen.dart`), 이룸이 정보 시트(`elumi_choice_sheets.dart`).

```
Pro 방식 누름
├─ canUseAiImageStyles = true  → 그냥 고름 (지금과 같음)
├─ 살 수 있음 (canPurchasePro) → 요금제 화면 열기 (그림 혜택 맨 위)
│    ├─ 닫힌 뒤 Pro가 됐으면 → 누른 방식을 고른 상태로 바꿈
│    └─ 아니면 → 고른 값 그대로 (Free 방식 유지, 팝업 없음)
└─ 살 수 없음 (스토어 꺼짐·상품 못 불러옴·이룸이 기기) → Pro 항목을 아예 보이지 않음
```

- "살 수 없으면 숨김"은 카드 내보내기 Pro 테마와 같은 기존 규칙(`canPurchaseProProvider` 주석: 살 방법이 없는데 잠금만 보이지 않게)을 따른다.
  - 단, **이미 Pro 방식이 저장된 Free 계정**에게는 그 항목을 숨기지 않고 보여 준다(고른 값이 화면에서 사라지면 안 됨). 따로 안내 줄은 두지 않는다.
- 잠금·배지 판단은 `features` 쪽에서 하고, `core/widgets/image_style_option_card.dart`에는 `isLocked`·`badge` 같은 값만 넘긴다(계층 규칙 `check_layer_imports`).
- 요금제 화면은 `plan_paywall_entry.dart`의 `openPlanPaywall`에 `highlight` 인자를 더해 연다(기존 호출부는 인자 없이 그대로).
- 온보딩 중(가입 직후)에도 같은 규칙. 가입 이벤트로 Pro 기간이 있는 계정은 그냥 고른다.

### 3.5 서버가 막는 것

| 경로 | 규칙 |
|---|---|
| `PATCH /api/member/image-style` (`MemberService.updateImageStyle`) | `drawsAiImages()` 방식인데 권한 꺼짐 > **403 `IMAGE_STYLE_NOT_ALLOWED`** ("캐릭터·사진 같은 그림은 Pro에서 쓸 수 있어요.") |
| 온보딩 완료 (`OnboardingService`) | 같은 경우 **거절하지 않고** Free 기본(`EMOJI`)으로 저장 + 경고 로그. 온보딩이 실패하면 안 된다 |
| 일과 만들기, 카드 추가, 그림 다시 그리기 | 저장값이 Pro 방식인데 권한 꺼짐 > 이번 생성은 `PHOTO_ONLY`(기호)로 진행. 저장값은 그대로 둔다(Pro로 돌아오면 다시 캐릭터) |

- 쓸 방식을 정하는 곳은 한 군데로 모은다: `EffectiveImageStyleResolver.resolve(memberId, storedStyle)` (가칭). 위 세 생성 경로가 모두 이것을 거친다.
- 이룸이 기기 계정은 연결해 준 보호자 기준으로 본다(주간 리포트와 같은 규칙).
- 새 ErrorCode는 앱 오류 표시 규칙대로 화면에 에러 코드가 보이게 한다(`E-STYLE` 유지).

### 3.6 이모지 카탈로그

**원본과 사본**

| 무엇 | 위치 | 비고 |
|---|---|---|
| 생성 스크립트 (단일 원본) | `server/tool/emoji/build_emoji_catalog.py` | 버전 고정 입력에서 아래 둘을 만든다 |
| 서버 카탈로그 | `server/src/main/resources/emoji/catalog.json` | Mulberry `pictograms/catalog.json`과 같은 형식 |
| 앱 사본 | `client/assets/emoji/catalog.json` + `client/assets/emoji/{id}.svg` + `LICENSE.txt` | 손으로 고치지 않는다 |

- 입력: `@twemoji/svg@15.0.0`(그림), `emojibase-data@15.3.0` en 라벨·그룹(이름과 분류). 버전은 스크립트에 고정한다.
- 고르는 범위: 단일 이모지만(피부색, ZWJ 조합, 국기, 기호 제외). 그룹은 사람 동작·휴식·운동·몸·손, 동물·식물, 음식·음료, 탈것·장소·날씨·시간, 활동, 물건. 얼굴 표정은 감정 관련 일부만. 목표 약 800개(Mulberry 811개와 비슷한 프롬프트 크기).
- id 형식: **`emoji_` + 영어 이름 snake_case** (예: `emoji_toothbrush`, `emoji_bus`). 사람이 읽는 이름이라 AI가 고르기 쉽고, `emoji_` 접두사로 Mulberry id와 한 칸(`pictogramId`)에서 섞여도 구분된다(Mulberry에는 `emoji`로 시작하는 id가 0개). 파일명도 id와 같게 두어 앱에서 변환표가 필요 없다.
- `fallbackId`: 그림이 없을 때 쓸 이모지 하나(내 판단: `emoji_star` 계열, 스크립트에서 정함).

**저장**

- 카드의 `pictogramId` 칸을 그대로 쓴다(길이 100, 접두사 포함해도 충분). DB 변경 없음.
- 앱 렌더링: id가 `emoji_`로 시작하면 이모지 에셋, 아니면 Mulberry. 표시 우선순위(사진 > AI 그림 > 예시 이미지 > 그림 기호)는 그대로다.

**AI가 고르는 경로**

- 지금은 `GeminiTextClient`가 `PictogramCatalog` 하나를 늘 싣는다(`input.put("pictogramCatalog", ...)`, 스키마 `hasPictogramCatalog`). 이를 **부르는 쪽이 방식에 맞는 카탈로그를 넘기게** 바꾼다. 입력 키 이름(`pictogramCatalog`)과 스키마 설명은 그대로 둔다(운영 DB 프롬프트를 건드리지 않기 위해).
- 카탈로그 선택: `PictogramCatalogs.forStyle(effectiveStyle)` (가칭) → EMOJI면 이모지, 그 외는 Mulberry. 일과 만들기(`RoutineAiPipeline`), 카드 추가(`PictogramPicker`) 둘 다 이것을 쓴다. 검증·폴백(`resolve`)도 같은 카탈로그로 한다.
- OpenAI·Claude 텍스트 클라이언트도 같은 입력을 쓰는지 확인하고 같이 맞춘다.
- 전문가 일과 입력 검증(`ExpertRoutineInputRules`)은 Mulberry만 허용하는 지금 규칙을 유지한다.

**라이선스 (Twemoji 그림: CC BY 4.0)**

- 오픈소스 라이선스 화면: `BundledLicenseKind`에 `twemoji` 추가, 그림 묶음에 이름·라이선스·출처 표기.
- 인쇄용 카드: 이모지가 들어간 장에는 Twemoji 출처 줄을 넣는다(`showsPictogramCredit`과 같은 방식).
- 약관 본문(`consent_documents.dart`)의 Mulberry 출처 문장은 **법적 문구라 손대지 않는다**(§6-3).

### 3.7 요금제 화면의 Pro 혜택 목록

- 앱 `PlanBenefit`에 지금 앱에 실제로 있는 Pro 기능을 모두 나열한다(서버 응답은 바꾸지 않음). 아래 표에서 한도 줄(일과 개수·이룸이 수·보관 일수)과 고품질 그림은 지금 Free·Pro 기본값이 같아(-1 무제한, 둘 다 꺼짐) 넣지 않는다.
- `highlight`로 넘어온 혜택은 맨 위로 올린다. 그림 방식에서 열면 "캐릭터·사진 같은 그림으로 카드를 만들어요"가 맨 위.
- 줄이 늘어도 시트 안에서 스크롤된다(지금 시트 틀이 큰 글자에서 스크롤함). 태블릿 카드도 같다.

혜택 줄 문구(ko, 해요체):

| 권한 | 문구 |
|---|---|
| AI_IMAGE_GENERATION | 캐릭터·사진 같은 그림으로 카드를 만들어요 |
| ADS_REMOVED | 광고 없이 써요 |
| ROUTINE_CREATE_PER_DAY / PER_WEEK | 일과를 더 많이 만들어요 |
| ROUTINE_MAX_COUNT | 일과를 더 많이 모아 둬요 |
| PROFILE_MAX_COUNT | 이룸이를 더 많이 등록해요 |
| HISTORY_RETENTION_DAYS | 기록을 더 오래 보관해요 |
| CARD_EXPORT_WITHOUT_WATERMARK | 인쇄용 카드에 로고와 워터마크가 없어요 (기존) |
| CARD_EXPORT_ALL_THEMES | 인쇄용 카드 디자인을 골라요 (기존) |
| WEEKLY_REPORT | 주간 리포트를 봐요 |
| ROUTINE_TRANSLATE | 만든 일과를 다른 언어로 만들어요 |
| ROUTINE_SCHEDULE | 요일마다 반복하고 이룸이 기기에 알려줘요 |
| GUARDIAN_VOICE | 보호자 목소리로 카드를 읽어줘요 |
| ROUTINE_TEMPLATES | 전문가 일과를 가져와요 |
| ROUTINE_MEMORY | 내가 고친 일과처럼 만들어 줘요 |
| IMAGE_REGENERATE_FREE | 그림을 크레딧 없이 다시 그려요 |
| IMAGE_HIGH_QUALITY | 더 선명한 그림을 받아요 |

- 표의 한도 줄 4개(일과 생성·보유, 이룸이 수, 보관 일수)와 IMAGE_HIGH_QUALITY는 이번에 넣지 않는다(위 이유). 실제 차이가 생기면 그때 더한다.

### 3.8 검토에서 나온 질문에 대한 결정 (내 판단)

- **공유·톡으로 나가는 이모지 id**: 바꾸지 않고 그대로 복사한다. 받는 쪽 새 앱은 이모지로, 옛 앱은 폴백으로 보인다(§4). 톡 일과가 전문가 일과로 넘어가는 경로는 없다(확인함). 관리자 화면의 그림 id 표시는 손대지 않는다.
- **Pro 방식이 저장된 Free 계정의 카드 추가·다시 그리기**: 앱도 서버와 같은 규칙으로 "실제로 쓸 방식"을 계산해(저장값이 Pro + 권한 꺼짐 > 기호) 기호 방식과 똑같이 동작한다. 그림 다시 그리기 버튼 노출도 이 값을 따른다.
  - 그림을 건너뛴 사유는 EMOJI·대체 모두 기존 `IMAGE_STYLE_PHOTO_ONLY`를 그대로 쓴다. 새 사유 코드를 만들지 않아 옛 앱이 그대로 읽는다. 앱 문구가 "직접 사진"을 뜻하면 "그림 기호를 넣었어요" 쪽 뜻으로 맞춘다.
- **이모지 고르기 품질 실측**: 하지 않는다(사용자: 꼭 필요한 것만). 고정 응답 테스트만 한다. 운영 폴백 비율은 기존 로그 `픽토그램 폴백 적용`으로 본다.
- **방식이 기호로 바뀌었다는 안내**: 두지 않는다(사용자: 꼭 필요한 것만). 일과 만들기 응답 형태도 바꾸지 않는다.

## 4. 실패 경로

| 상황 | 동작 |
|---|---|
| 이모지 카탈로그 파일이 없거나 깨짐 (서버) | 빈 카탈로그 + 경고 로그. 이모지 방식 카드는 Mulberry 카탈로그로 대체해 고른다(그림이 빈 카드보다 낫다) |
| AI가 목록에 없는 id를 줌 | 그 방식 카탈로그의 `fallbackId`로 바꿈 (지금 Mulberry와 같은 규칙, 로그 `픽토그램 폴백 적용`) |
| 앱에 해당 이모지 SVG가 없음 (옛 앱 / 사본 누락) | 이모지 id를 모르는 옛 앱은 허용 id 검사에서 걸러 폴백 그림이나 기본 카드를 보인다. 새 앱은 기본 카드로 그린다. 카드가 깨지거나 앱이 죽지 않는다 |
| 옛 앱이 서버에서 `EMOJI`를 받음 | `fromApiValue`가 모르는 값이라 캐릭터로 표시된다(표시만 어긋남). 실제 생성은 서버가 정한다. 알려진 한계로 둔다 |
| Free가 Pro 방식 PATCH (옛 앱·직접 호출) | 403 `IMAGE_STYLE_NOT_ALLOWED`. 옛 앱은 기존 실패 처리(`E-STYLE`, 이전 값 복원)를 탄다 |
| Pro가 끝나 Free로 돌아감 | 저장값 유지, 생성은 기호로 |
| 요금제 화면에서 결제 실패·취소 | 고른 값 그대로(Free 방식). 결제 실패 처리는 기존 요금제 화면 몫 |

## 5. 검증

- 서버: 바꾼 곳만 겨눈 테스트(`./gradlew test --tests ...`). 실제 AI는 부르지 않고 응답을 고정한다.
  - 방식별 카탈로그 선택, `emoji_` id 검증·폴백, Pro 방식 PATCH 403, 온보딩은 EMOJI로 저장, Free+CARTOON 저장값의 생성은 PHOTO_ONLY로.
- 앱: `flutter analyze` + `tool/check_*` 4종. 시뮬레이터 실측 캡처(라이트·다크): 온보딩 그림 방식(Free, Pro), 설정 그림 방식, Pro 누름 > 요금제 화면(그림 줄 맨 위), 이모지 카드가 붙은 일과 화면.
- 이모지 카탈로그: 스크립트로 만든 개수, 모든 id에 SVG가 있는지, 서버·앱 사본이 같은지 스크립트 끝에서 확인.

## 6. 사용자가 정한 것 (2026-11-05)

1. 화면 이름: 이모지 그림 / 그림 기호 / 캐릭터 그림 / 사진 같은 그림 (§3.2)
2. 운영의 Free `AI 맞춤 삽화` 설정은 **배포하는 날 같이 끈다.** 끄는 작업은 그때 다시 확인받고 관리자 화면에서 한다(코드 작업 아님)
3. 약관 본문은 그대로 둔다. Twemoji 출처는 오픈소스 라이선스 화면과 인쇄용 카드에만 넣는다

## 7. 구현하는 사람에게 맡기는 것

- 이모지 선별 세부(어떤 하위 그룹을 몇 개), fallback 이모지 하나
- `EffectiveImageStyleResolver`, `PictogramCatalogs` 실제 이름과 위치(계층 규칙 안에서)
- 앱에서 Pro 항목 숨김·배지의 정확한 배치
