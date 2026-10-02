# 다국어 7 — 법무 검토 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> 이 문서는 마스터 계획 `2026-10-02-i18n-0-master.md` 의 하위 계획 7이다. **코드 작업이 아니다.** 산출물은 질문지(체크리스트) 문서와 언어별 출시 게이트 기록 양식이고, 결론은 법무 검토자가 낸다. 마스터 순서표에서 이 계획은 **가장 먼저 시작해** 1~6 과 병렬로 가며 언어별 출시를 막는다.
> 이 문서의 Step 은 "문서 작성 → 검토자 확인 → 기록" 순서다. 법무 담당이 **미정**이므로, 검토자 전달 Step 은 담당이 정해진 뒤에 한다(Task 1 이 담당 칸을 만든다).

**Goal:** 새 언어가 새 법역으로 나가기 전에 법무가 답해야 하는 질문을 코드·문서 근거와 함께 한 곳에 모으고, 답이 나온 것을 언어별 출시 게이트로 기록한다. 아울러 DLP 폐기(#377) 뒤에도 남은 "로컬 LLM 이라 외부 전송 없음" 서술을 사실에 맞게 정정한다.

**Architecture:** `docs/i18n/legal/` 에 **항목 시트 9개**(질문 · 근거 경로 · 산출물 · 답변 기록 · 게이트 반영)와 **게이트 기록 표**(`launch-gates.md`)를 둔다. 질문은 코드를 읽고 쓴 구체적인 것이고, 근거 경로는 스크립트(`check-evidence.sh`)가 실제로 있는지 검사한다. 작성자가 알고 있는 법 지식은 "알고 있는 바 — 확인 필요"로 표시하고 사실로 쓰지 않는다. 결과를 코드에 반영하는 일(약관 문구 · 키 구조 · 광고 지역)은 이 계획이 하지 않고 담당 계획(4)이나 새 이슈로 넘긴다.

**Tech Stack:** Markdown 문서, bash(근거 경로 검사). 코드 변경 없음.

**Spec:** `docs/superpowers/specs/2026-10-02-multi-language-design.md` (4.4 · 5장 · 7장 7번 · 8장 · 9장)

## Global Constraints

- 지원 언어는 `ko` `en` `ja` `zh`(간체) `es` 다섯이다. RTL과 번체 중국어는 범위 밖이다.
- **앱 안에는 언어 선택 화면을 만들지 않는다.** 언어 강제 스위치는 개발자 도구(`core/dev`)에만 둔다.
- 대체 순서는 어디서든 **요청 언어 → `en` → `ko`** 이다. 단 요청 언어가 `ko` 이면 `ko` 만 본다(한국어 사용자에게 영어를 보이지 않는다).
- `Accept-Language` 헤더가 **없으면 `ko`**, 5개 밖이거나 깨진 값이면 `en` 이다. 이미 배포된 앱의 응답은 바뀌지 않는다.
- 에러 문구는 서버가 번역해 내려보내고 클라이언트는 서버 문구를 그대로 보여준다(#347). 클라이언트가 에러 코드를 번역하지 않는다.
- `ko` 화면은 **1단계 이후에도 지금과 픽셀 단위로 같다.** 기존 앱 테스트와 골든이 그대로 통과해야 한다.
- 일과의 콘텐츠 언어는 일과를 만든 요청의 화면 언어이고, 보호자가 고르지 않는다.
- 약관은 그 언어의 게시본이 있어야 그 언어를 연다. 없는 언어에서 `en` 약관으로 대체하지 않는다.
- 서비스 원칙 유지: 진단명 미수집, 보호자 승인 후 노출, 원문 로그 미저장, AI 실패 시 fallback 필수.
- 용어: `이룸이`(아이·아동 금지), 해요체·능동형·긍정형(한국어 기준). 번역 용어는 용어집(`docs/i18n/glossary.md`)을 따른다.
- 코드 주석은 간결한 한국어(WHY 중심). 커밋은 `/pro-commit`으로, 이슈 번호 연결, `Co-Authored-By` 금지, 푸시는 사용자 요청 시에만.
- AI 호출은 비용이다. 검증용으로 생성 API를 반복 호출하지 않고 언어당 가장 싼 모델로 최소 횟수만 쓴다.
- Flyway 번호는 아래 표가 임시 배정이다. 구현 시점에 `origin/develop`의 다음 빈 번호를 쓴다(번호가 겹치면 먼저 머지된 쪽이 이긴다).

## Review Focus

마스터 `Review Focus` 8줄은 모두 다른 계획이 소유한다. 이 계획이 소유한 줄은 없다. 아래는 **이 계획이 더한** 항목이다.

- 법무 항목이 하나라도 안 닫힌 언어는 열리지 않는다 — `launch-gates.md` 의 그 언어 열이 전부 `닫힘`/`해당 없음` 이어야 한다. (Task 1, 12)
- 법무 질문의 근거가 **사실과 다른 문서**(DLP 로컬 LLM 서술)를 따르지 않는다. (Task 2)
- 법적 문구의 번역·변경은 법무 확정본으로만 한다 — 이 계획은 확정본을 받을 자리만 만든다. (Task 3~11)

## 이 계획이 확인한 것 (코드·문서에서 직접 읽은 사실)

질문이 이 사실들 위에 서 있다. 문서를 쓰기 전에 알아 둘 것.

| 사실 | 근거 |
| --- | --- |
| 국외 이전 동의에 적힌 업체는 Google · OpenAI · fal 셋이고 모두 미국이다. 코드가 부르는 것도 같다(텍스트 Gemini·OpenAI, 이미지 Gemini·OpenAI·FLUX) | `server/src/main/resources/consent/overseas.txt` · `server/src/main/java/com/chuseok22/elumserver/ai/core/ImageProvider.java` |
| 동의 문서에 **없는** 전송: 이룸이 휴대폰이 카드 문구를 별도 TTS 서버로 보낸다 | `client/lib/features/child/data/speech_service.dart` |
| 보호자 입력은 가공 없이 AI 업체로 간다(DLP 폐기) | `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineService.java:134` |
| 이용약관에 **준거법 · 관할 · 분쟁 해결 조항이 없다** | `server/src/main/resources/consent/terms.txt` |
| 광고 동의는 iOS ATT 뿐이다. UMP(EU 동의) 코드가 없다 | `client/lib/core/ads/ad_consent.dart` · `client/lib/core/ads/ad_sdk.dart` |
| 방침에 사진 수집이 없는데 앱은 보호자 사진을 서버에 올린다 | `server/src/main/resources/consent/privacy.txt` · `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineStepPhotoService.java` |
| 스토어 신고(2026-09-21)는 광고 없음·광고 ID 미사용인데 지금 앱은 광고 ID 를 쓴다. 배포는 175개국 | `docs/projectops/store/20260921_스토어_문구_원본.md` |
| 개인정보방침 게시본·검사기는 한국어 페이지 하나뿐이다 | `tool/check_public_pages.py` |
| 한국어 스토어 설명에 "먼저 가린 뒤에 카드를 만든다"는 사실과 다른 문장이 있었다(계획 6 Task 7 이 레포 원본을 정정, 콘솔 값은 사용자가 갱신) | `docs/projectops/store/20260921_스토어_문구_원본.md` |

**근거 경로는 `origin/develop` 기준이다.** 계획 4 가 약관 본문을 `server/src/main/resources/consent/<파일>.txt` 에서 `consent/ko/<파일>.txt` 로 옮긴다(`git mv`, 내용 불변). 옮겨진 뒤에는 시트가 인용한 `consent/*.txt` 경로가 사라지는데, `check-evidence.sh` 가 이를 `옮겨짐(시트의 경로를 … 로 고친다)` 로 알려 준다 — 알림이 나오면 시트의 경로를 새 경로로 고친다(검사는 실패하지 않는다).

---

## Task 1: 폴더 · 담당 · 게이트 기록 양식 · 근거 경로 검사기

**Files:**
- Create: `docs/i18n/legal/README.md`
- Create: `docs/i18n/legal/launch-gates.md`
- Create: `docs/i18n/legal/check-evidence.sh`

**Interfaces:**
- Consumes: 스펙 5장의 언어 오픈 조건(번역 · 약관 게시 · 프롬프트 검증), 계획 5 의 언어 오픈 체크리스트(`docs/i18n/language-launch-checklist.md`)
- Produces: 항목 목록과 상태 정의, **언어별 게이트 표 + 서명 양식**, 항목 시트가 인용한 경로를 검사하는 스크립트. 담당(법무 검토자)은 `미정` 이다.

- [ ] **Step 1: README 를 만든다**

`docs/i18n/legal/README.md`:

````markdown
# 법무 검토 — 다국어 출시 차단 항목

> 이슈 [#521](https://github.com/Twin-Fang/elum/issues/521) · 스펙 `docs/superpowers/specs/2026-10-02-multi-language-design.md` 7장 7번 · 하위 계획 `2026-10-02-i18n-7-legal-review.md`
>
> **코드 작업이 아니다.** 1~6 계획과 병렬로 진행하며, 항목이 닫히지 않은 언어는 열지 않는다(언어별 출시 게이트).

## 이 문서의 성격

- 이 문서는 **질문지**다. 법률 자문이 아니고, 결론을 내리지 않는다. 결론은 법무 검토자가 내고 **그 답변을 이 폴더에 기록**한다.
- 질문마다 **코드·문서에서 직접 확인한 사실**(경로를 적었다)과 **작성자가 알고 있는 바**를 구분했다.
  `알고 있는 바 — 확인 필요` 라고 적힌 것은 법무가 틀렸다고 해도 이상하지 않은 기억이다. 사실로 쓰지 않는다.
- 법적 효력이 있는 문장(약관 · 개인정보방침 · 동의 문구)은 임의로 바꾸지 않는다. 바꾸려면 근거를 남기고 확인을 받는다
  (루트 `CLAUDE.md`). 이 폴더의 산출물이 그 근거다.

## 담당

| 역할 | 하는 일 | 담당 |
| --- | --- | --- |
| 법무 검토자 | 질문에 답하고 산출물(확정 문구 · 결론표)을 만든다. 언어마다 그 법역을 아는 사람이 필요할 수 있다 | 미정 |
| 개발 담당 | 코드 근거 확인, 답변을 약관 · 화면 · 서버 설정에 반영 | 사용자 |
| 제품 결정 | 출시 국가, 광고 노출 지역, 연령 기준 같은 제품 쪽 선택 | 사용자 |

## 항목

| # | 파일 | 한 줄 | 영향 |
| --- | --- | --- | --- |
| 01 | [01-overseas-transfer.md](./01-overseas-transfer.md) | 국외 이전 동의(Google · OpenAI · fal.ai · 그 밖의 이전처) | 모든 언어 |
| 02 | [02-age-consent.md](./02-age-consent.md) | 연령 동의(KR 14 · GDPR 16 · COPPA 13 · 일본) | 언어별 |
| 03 | [03-special-category.md](./03-special-category.md) | 자유 입력과 사진의 특수범주(GDPR · APPI 요배려) | 모든 언어 |
| 04 | [04-guardianship.md](./04-guardianship.md) | 법정대리인 · 성인 후견 구조의 법역별 효력 | 언어별 |
| 05 | [05-ads-consent.md](./05-ads-consent.md) | 광고 ID · ATT · EU 동의(UMP) | en · es(EEA) 우선 |
| 06 | [06-store-declarations.md](./06-store-declarations.md) | 스토어 신고서(App Privacy · Data safety · 등급 · 배포 국가) | 모든 언어 |
| 07 | [07-terms-governing-law.md](./07-terms-governing-law.md) | 약관 준거법 · 관할 · 우선 언어 | 언어별 |
| 08 | [08-privacy-page-per-language.md](./08-privacy-page-per-language.md) | 개인정보방침 게시본 언어별 | 언어별 |
| 09 | [09-language-vs-jurisdiction.md](./09-language-vs-jurisdiction.md) | 언어와 법역 축(스펙 4.4) | 모든 언어 |

출시 게이트는 [launch-gates.md](./launch-gates.md) 에 기록한다. 항목 파일의 `상태` 는 아래 넷 중 하나다.

| 상태 | 뜻 |
| --- | --- |
| 미착수 | 법무 담당이 정해지지 않았거나 질문을 아직 안 보냈다 |
| 질문 전달 | 검토자에게 보냈다(날짜를 적는다) |
| 답변 받음 | 답변을 `답변 기록` 표에 옮겼다. 산출물은 아직일 수 있다 |
| 닫힘 | 산출물이 있고, 필요한 코드·문서 반영이 끝났고, `launch-gates.md` 를 채웠다 |

## 진행 순서

1. 법무 담당을 정한다(위 표 `미정` 을 채운다).
2. 항목 파일의 질문을 검토자에게 보낸다. 항목 파일과 근거 파일을 함께 준다. 상태를 `질문 전달` 로 바꾸고 날짜를 적는다.
3. 답변을 `답변 기록` 표에 옮긴다(날짜 · 답변자 · 질문 번호 · 결론 · 근거 문서). **구두 답변은 기록으로 치지 않는다** — 문서나 메일 링크를 붙인다.
4. 산출물을 만든다. 문구 변경이 있으면 약관·화면에 반영하는 일은 하위 계획 4(약관·공지)와 개발 담당이 한다.
5. `launch-gates.md` 의 해당 언어 칸을 채운다.
6. 모든 칸이 닫힌 언어만 `docs/i18n/launched-locales.txt` 에 더한다(계획 5 의 언어 오픈 체크리스트).
````

- [ ] **Step 2: 게이트 기록 양식을 만든다**

`docs/i18n/legal/launch-gates.md`:

`````markdown
# 언어별 출시 게이트 기록

> 이슈 [#521](https://github.com/Twin-Fang/elum/issues/521) · 항목은 [README.md](./README.md) 의 01~09.
> 언어를 여는 PR 은 이 표에서 **그 언어 열이 전부 `닫힘` 또는 `해당 없음`** 인 것을 근거로 한다.

## 쓰는 법

- 칸에는 `미결` · `닫힘 <날짜> <확인자>` · `해당 없음(<사유>)` 중 하나를 쓴다.
- `닫힘` 은 항목 파일의 상태가 `닫힘` 일 때만 쓴다. 근거는 항목 파일의 `답변 기록` 에 있다.
- `해당 없음` 은 법무 검토자가 그렇다고 답한 경우만 쓴다. 개발 쪽 판단으로 쓰지 않는다.
- ko 열은 현행 서비스다(기준). 새로 막을 것이 아니라 **새 언어가 현행과 다른 법역으로 나가는 것**을 막는다.

## 항목별 게이트

| # | 항목 | ko(현행) | en | es | ja | zh |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | 국외 이전 동의 | 기준 | 미결 | 미결 | 미결 | 미결 |
| 02 | 연령 동의 | 기준 | 미결 | 미결 | 미결 | 미결 |
| 03 | 자유 입력 · 사진 특수범주 | 기준 | 미결 | 미결 | 미결 | 미결 |
| 04 | 법정대리인 · 성인 후견 | 기준 | 미결 | 미결 | 미결 | 미결 |
| 05 | 광고 ID · ATT · EU 동의 | 기준 | 미결 | 미결 | 미결 | 미결 |
| 06 | 스토어 신고서 · 배포 국가 | 기준 | 미결 | 미결 | 미결 | 미결 |
| 07 | 약관 준거법 · 관할 | 기준 | 미결 | 미결 | 미결 | 미결 |
| 08 | 개인정보방침 게시본 | 기준 | 미결 | 미결 | 미결 | 미결 |
| 09 | 언어와 법역 | 기준 | 미결 | 미결 | 미결 | 미결 |

## 언어별 서명 (언어를 여는 결정)

스펙 5장의 세 조건(번역 · 약관 게시 · 프롬프트 검증)과 위 법무 게이트를 한 곳에 모은다. **한 언어씩** 채운다.

### 양식

```text
언어:            <en | es | ja | zh>
해당 법역:        <법무가 확정한 국가·지역 목록>
번역 파일 완성:    <예 / 아니오>   근거: <CI 실행 링크 · PR>
약관 게시:        <예 / 아니오>   근거: <관리자 화면 게시 버전 · 외부 게시 URL>
프롬프트 검증:     <예 / 아니오>   근거: <이슈 댓글 링크>
법무 게이트 01~09: <전부 닫힘 / 미결 항목 번호>
열기로 결정한 사람: <이름>        날짜: <YYYY-MM-DD>
launched-locales.txt 반영 커밋: <해시>
ENABLED_CONTENT_LOCALES 반영일: <YYYY-MM-DD>
```

### en

```text
언어:            en
해당 법역:        (법무 확정 전)
번역 파일 완성:    (아직)
약관 게시:        (아직)
프롬프트 검증:     (아직)
법무 게이트 01~09: 미결 (01 02 03 04 05 06 07 08 09)
열기로 결정한 사람: (아직)
launched-locales.txt 반영 커밋: (아직)
ENABLED_CONTENT_LOCALES 반영일: (아직)
```

### es

```text
언어:            es
해당 법역:        (법무 확정 전 — 스페인 · 중남미 변종 결정 필요)
번역 파일 완성:    (아직)
약관 게시:        (아직)
프롬프트 검증:     (아직)
법무 게이트 01~09: 미결 (01 02 03 04 05 06 07 08 09)
열기로 결정한 사람: (아직)
launched-locales.txt 반영 커밋: (아직)
ENABLED_CONTENT_LOCALES 반영일: (아직)
```

### ja

```text
언어:            ja
해당 법역:        (법무 확정 전)
번역 파일 완성:    (아직)
약관 게시:        (아직)
프롬프트 검증:     (아직)
법무 게이트 01~09: 미결 (01 02 03 04 05 06 07 08 09)
열기로 결정한 사람: (아직)
launched-locales.txt 반영 커밋: (아직)
ENABLED_CONTENT_LOCALES 반영일: (아직)
```

### zh

```text
언어:            zh
해당 법역:        (법무 확정 전 — 간체 사용 지역)
번역 파일 완성:    (아직)
약관 게시:        (아직)
프롬프트 검증:     (아직)
법무 게이트 01~09: 미결 (01 02 03 04 05 06 07 08 09)
열기로 결정한 사람: (아직)
launched-locales.txt 반영 커밋: (아직)
ENABLED_CONTENT_LOCALES 반영일: (아직)
```
`````

- [ ] **Step 3: 근거 경로 검사기를 만든다**

항목 시트는 코드·문서 경로를 근거로 든다. 경로가 틀리면 법무가 잘못된 파일을 본다. 시트가 인용한 경로가 실제로 있는지 본다. 계획 5·6 이 만드는 파일은 아직 없을 수 있어 건너뛴다.

`docs/i18n/legal/check-evidence.sh`:

```bash
#!/usr/bin/env bash
# docs/i18n/legal/*.md 가 인용한 파일 경로가 실제로 있는지 본다 (레포 루트에서 실행: bash docs/i18n/legal/check-evidence.sh).
# 백틱 안의 경로 중 server/ client/ docs/ tool/ .github/ 로 시작하는 것만 본다. `:줄번호` 는 떼고 본다.
# 계획 5·6 이 만들 파일(아직 없을 수 있는 것)은 MAY_MISSING 에 적어 건너뛴다.
set -u
MAY_MISSING='docs/projectops/store/i18n/README.md|docs/i18n/glossary.md|docs/i18n/translation-workflow.md|docs/i18n/launched-locales.txt|client/ios/fastlane/store/'
missing=0
while IFS= read -r path; do
  base="${path%%:*}"
  [ -e "$base" ] && continue
  # 계획 4 가 약관 본문을 consent/<언어>/ 로 옮기면 consent/X.txt 는 consent/ko/X.txt 가 된다.
  moved="$(printf '%s' "$base" | sed -E 's#(server/src/main/resources/consent/)([a-z]+\.txt)#\1ko/\2#')"
  if [ "$moved" != "$base" ] && [ -e "$moved" ]; then
    echo "옮겨짐(시트의 경로를 $moved 로 고친다): $base"
    continue
  fi
  if printf '%s' "$base" | grep -Eq "$MAY_MISSING"; then
    echo "건너뜀(다른 계획이 만든다): $base"
    continue
  fi
  echo "❌ 없는 경로: $base"
  missing=1
done < <(grep -hoE '`(server|client|docs|tool|\.github)/[^` ]+`' docs/i18n/legal/*.md | tr -d '`' | sort -u)
[ "$missing" -eq 0 ] && echo "인용한 경로가 모두 있다"
exit "$missing"
```

- [ ] **Step 4: 검사기가 동작하는지 본다**

Run: `chmod +x docs/i18n/legal/check-evidence.sh && bash docs/i18n/legal/check-evidence.sh`
Expected: 이 시점에는 항목 시트(01~09)가 아직 없으므로 인용 경로가 `README.md`·`launch-gates.md` 것뿐이다. 종료 코드 0 과 `인용한 경로가 모두 있다` 가 나온다. 시트를 더한 뒤 같은 명령을 다시 돌려 없는 경로가 `❌ 없는 경로: …` 로 나오는지 확인한다(항목 Task 마다 한다).

- [ ] **Step 5: 법무 담당을 정한다 (사용자 결정)**

`docs/i18n/legal/README.md` 의 담당 표 `미정` 을 사용자가 정한 사람으로 바꾼다. 언어별로 법역을 아는 사람이 다를 수 있으면 `launch-gates.md` 의 언어별 서명 양식 아래에 `법무 확인자` 줄을 더한다. 정해지기 전에는 이 Step 을 열어 두고 이슈 #521 에 "담당 미정으로 시트까지만 만들었다"고 적는다.

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/README.md docs/i18n/legal/launch-gates.md docs/i18n/legal/check-evidence.sh
```

---

## Task 2: 문서 정정 — DLP 폐기 뒤에도 남은 "외부 전송 없음" 서술

**Files:**
- Modify: `docs/05-ai-dlp-gateway.md` (17행 · 147행 · 186행)
- Modify: `docs/02-architecture.md` (「로컬 LLM 사용에 따른 보안 서사」 절, 103~108행)

**Interfaces:**
- Consumes: 서비스 원칙 2(가린다고 말하지 않는다), 이슈 #377(DLP 폐기, 2026-09-23), `server/src/main/resources/consent/overseas.txt`
- Produces: 법무 검토 근거 문서에서 사실과 다른 문장을 없앤다(옛 문장은 취소선으로 남긴다).

**왜 먼저 하나.** 스펙 9장: `docs/05-ai-dlp-gateway.md` 가 "로컬 LLM 이라 외부 전송 없음"으로 적혀 있으나 DLP 는 #377 에서 폐기됐다. **법무 검토 전에 문서를 현재 사실에 맞춘다.** 법무 검토자가 이 문서를 읽고 "외부로 안 나간다"고 오해하면 질문 01·03 의 전제가 무너진다.

**지금 상태(읽고 확인한 것).** 이 문서들에는 이미 머리 경고("현재 동작과 다른 문서예요 … 2026-09-23부터 쓰지 않으며(#377)")가 있다. 그런데 **본문 문장이 그대로 남아** 경고를 못 본 채 본문만 읽으면 거짓을 읽는다. 경고를 지우지 않고 본문의 거짓 문장 네 곳을 고친다. 같은 서술이 `02-architecture.md` 에도 있어 함께 고친다(같은 사실, 같은 근거). `docs/07-mvp-scope.md` 46행의 "최소화된 문장만 로컬 LLM에 전달"은 해커톤 시연 흐름의 목록이라 머리 경고로 충분하다고 보고 고치지 않는다.

이 문서들은 법적 효력이 있는 문장이 아니다(약관 · 개인정보방침 · 동의 문구가 아니다). 그래서 정정할 수 있고, 근거(#377)를 문장에 남긴다.

수정 전/후(실제 스크립트 결과):

```diff
--- a/docs/05-ai-dlp-gateway.md
+++ b/docs/05-ai-dlp-gateway.md
@@ -14,7 +14,8 @@
 
 - "완성형 AI DLP 솔루션을 개발했다"라고 표현하지 않는다 — 과장으로 보일 수 있음. 위 정의대로 **입력 보호 계층**으로 정확히 소개한다.
 - 위치: **Spring 서비스 서버 내부 모듈**. LLM과 맞닿는 유일한 지점. (초기 안의 Flask AI 서버는 폐기)
-- LLM은 **기 구축된 로컬 LLM**이라 데이터가 외부 서비스로 나가지 않지만, "모델이 알 필요 없는 정보는 프롬프트에도 넣지 않는다"는 **최소 정보 원칙**으로 DLP는 그대로 유지한다.
+- **정정(2026-10-02, #377):** 카드 글과 그림은 외부 AI 업체(Google LLC · OpenAI, L.L.C. · Features & Labels Inc.(fal), 모두 미국)가 만들고, 보호자가 쓴 문장은 **가공 없이 그대로** 전달된다. 로컬 LLM 과 AI DLP 는 2026-09-23 부터 쓰지 않는다(#377). 지금의 보호 수단은 보호자에게 개인정보를 적지 말라고 안내하는 것이다.
+  ~~설계 당시: LLM은 기 구축된 로컬 LLM이라 데이터가 외부 서비스로 나가지 않지만, "모델이 알 필요 없는 정보는 프롬프트에도 넣지 않는다"는 최소 정보 원칙으로 DLP는 그대로 유지한다.~~
 
 ## 핵심 카피
 
@@ -144,7 +145,7 @@
 - 3단계 진행 표시 중 2단계에서 보안을 가장 강조:
   > ✓ **AI DLP로 개인정보를 보호했어요**
   > 이름과 학교 정보는 안전하게 가렸어요.
-- 하단 고정 문구: 🔒 원문은 AI에 그대로 전달되지 않아요.
+- 하단 고정 문구(설계 당시): ~~🔒 원문은 AI에 그대로 전달되지 않아요.~~ **쓰지 않는 문구다(#377).** 원문은 가공 없이 전달되므로 화면에서 "가린다 · 안전하게 보호한다"고 말하지 않는다(루트 `CLAUDE.md` 서비스 원칙 2).
 - 상태 문구 표현 후보 (탐지 로직을 나열하지 말고 **무엇을 보호했는지만** 보여줄 것):
   1. "이름과 학교 정보를 안전하게 가렸어요." ← 사용자 화면에 가장 자연스러움 (추천)
   2. "이룸이 식별 정보와 기관 정보를 보호했어요." (조금 더 기술적)
@@ -183,7 +184,7 @@
 
 ## 미확정 사항
 
-- **발표 카피 재조정**: 로컬 LLM 전환으로 "외부 AI에 보내지 않는다" 서사가 "데이터가 서버 밖으로 나가지 않는다 + 모델에도 최소 정보만 준다"의 이중 구조로 더 강해질 수 있음 — 발표 문구 다듬기 필요
+- ~~**발표 카피 재조정**: 로컬 LLM 전환으로 "외부 AI에 보내지 않는다" 서사가 "데이터가 서버 밖으로 나가지 않는다 + 모델에도 최소 정보만 준다"의 이중 구조로 더 강해질 수 있음~~ **폐기(#377).** 로컬 LLM 을 쓰지 않으므로 "데이터가 서버 밖으로 나가지 않는다"는 서사는 사실이 아니다. 발표·스토어 문구에서 쓰지 않는다.
 - DLP UI: 로딩 통합안 vs 별도 페이지안 최종 결정
 - 프롬프트 인젝션 검사 패턴 목록
 - 학교/기관 일반화 패턴의 범위 (초·중·고 외 복지관, 병원 등)
--- a/docs/02-architecture.md
+++ b/docs/02-architecture.md
@@ -100,12 +100,11 @@
 이룸이 화면
 ```
 
-## 로컬 LLM 사용에 따른 보안 서사 (참고)
+## 로컬 LLM 사용에 따른 보안 서사 (정정됨)
 
-- 로컬 LLM이므로 **데이터가 외부 서비스로 나가지 않는다는 것 자체**가 추가 보안 포인트가 된다.
-- 그래도 AI DLP Gateway는 유지한다 — "모델이 알 필요 없는 정보는 프롬프트에도 넣지 않는다"는
-  **최소 정보 원칙**은 로컬·외부와 무관하게 성립하고, 발표 서사의 핵심이다.
-- 발표 카피의 "외부 AI" 표현은 "AI/LLM"으로 조정 필요. → [05-ai-dlp-gateway.md](./05-ai-dlp-gateway.md) 미확정 사항 참고
+- **정정(2026-10-02, #377):** 카드 글과 그림은 외부 AI 업체(Google LLC · OpenAI, L.L.C. · Features & Labels Inc.(fal), 모두 미국)가 만들고, 보호자가 쓴 문장은 **가공 없이 그대로** 전달된다. 로컬 LLM 과 AI DLP 는 2026-09-23 부터 쓰지 않는다(#377).
+- 이 절이 말하던 "로컬 LLM 이므로 데이터가 외부 서비스로 나가지 않는다"와 "AI DLP Gateway 는 유지한다"는 사실이 아니다.
+  현재 기준은 [개인정보처리방침](https://twin-fang.github.io/elum/privacy.html)과 서버 `consent/overseas.txt` 다.
 
 ## 이미지 전략 (MVP 제약)
 
```

- [ ] **Step 1: 고칠 줄이 지금 있는지 확인한다**

Run: `grep -n "LLM은 \*\*기 구축된 로컬 LLM\*\*이라\|하단 고정 문구: 🔒\|발표 카피 재조정\|로컬 LLM이므로" docs/05-ai-dlp-gateway.md docs/02-architecture.md`
Expected: `05-ai-dlp-gateway.md` 에서 세 줄(17 · 147 · 186행)과 `02-architecture.md` 한 줄(105행)이 나온다. 이미 누가 고쳤다면 해당 줄이 안 나온다 — 그 경우 아래 스크립트가 앵커를 못 찾아 멈추므로 고친 줄은 스크립트 목록에서 지우고 돌린다.

- [ ] **Step 2: 정정 스크립트를 실행한다**

줄의 앞부분(접두사)이 정확히 한 줄과 맞지 않으면 멈추고 **아무 파일도 쓰지 않는다.** 옛 문장은 취소선(`~~`)으로 남긴다.

```python
# DLP 폐기(#377) 뒤에도 남은 "로컬 LLM 이라 외부 전송 없음" 서술을 사실에 맞게 정정한다.
# 레포 루트에서 실행: python3 이 파일. 줄 앞부분(접두사)이 정확히 한 줄과 맞지 않으면 멈추고 아무것도 쓰지 않는다.
# 옛 문장은 지우지 않고 취소선으로 남긴다 — 설계 당시에 무엇을 가정했는지가 기록이다.
import pathlib

DOCS = pathlib.Path('docs')
FACT = (
    '카드 글과 그림은 외부 AI 업체(Google LLC · OpenAI, L.L.C. · Features & Labels Inc.(fal), 모두 미국)가 만들고, '
    '보호자가 쓴 문장은 **가공 없이 그대로** 전달된다. 로컬 LLM 과 AI DLP 는 2026-09-23 부터 쓰지 않는다(#377).'
)

# (파일, 줄 접두사, 새 줄) — 접두사로 한 줄을 통째로 바꾼다.
LINE_EDITS = [
    (
        '05-ai-dlp-gateway.md',
        '- LLM은 **기 구축된 로컬 LLM**이라',
        '- **정정(2026-10-02, #377):** ' + FACT + ' 지금의 보호 수단은 보호자에게 개인정보를 적지 말라고 안내하는 것이다.\n'
        '  ~~설계 당시: LLM은 기 구축된 로컬 LLM이라 데이터가 외부 서비스로 나가지 않지만, "모델이 알 필요 없는 정보는 프롬프트에도 넣지 않는다"는 최소 정보 원칙으로 DLP는 그대로 유지한다.~~',
    ),
    (
        '05-ai-dlp-gateway.md',
        '- 하단 고정 문구: 🔒 원문은 AI에 그대로 전달되지 않아요.',
        '- 하단 고정 문구(설계 당시): ~~🔒 원문은 AI에 그대로 전달되지 않아요.~~ **쓰지 않는 문구다(#377).** '
        '원문은 가공 없이 전달되므로 화면에서 "가린다 · 안전하게 보호한다"고 말하지 않는다(루트 `CLAUDE.md` 서비스 원칙 2).',
    ),
    (
        '05-ai-dlp-gateway.md',
        '- **발표 카피 재조정**: 로컬 LLM 전환으로',
        '- ~~**발표 카피 재조정**: 로컬 LLM 전환으로 "외부 AI에 보내지 않는다" 서사가 "데이터가 서버 밖으로 나가지 않는다 + 모델에도 최소 정보만 준다"의 이중 구조로 더 강해질 수 있음~~ '
        '**폐기(#377).** 로컬 LLM 을 쓰지 않으므로 "데이터가 서버 밖으로 나가지 않는다"는 서사는 사실이 아니다. 발표·스토어 문구에서 쓰지 않는다.',
    ),
]

# 02-architecture.md 의 "로컬 LLM 사용에 따른 보안 서사" 절 전체(제목 다음 줄부터 다음 `## ` 앞까지)를 바꾼다.
SECTION_FILE = '02-architecture.md'
SECTION_TITLE = '## 로컬 LLM 사용에 따른 보안 서사 (참고)'
SECTION_BODY = (
    '- **정정(2026-10-02, #377):** ' + FACT + '\n'
    '- 이 절이 말하던 "로컬 LLM 이므로 데이터가 외부 서비스로 나가지 않는다"와 "AI DLP Gateway 는 유지한다"는 사실이 아니다.\n'
    '  현재 기준은 [개인정보처리방침](https://twin-fang.github.io/elum/privacy.html)과 서버 `consent/overseas.txt` 다.'
)

# ---- 적용 (먼저 전부 검증한 뒤에만 쓴다) ----
texts = {}


def load(name):
    if name not in texts:
        texts[name] = (DOCS / name).read_text(encoding='utf-8')
    return texts[name]


for name, prefix, new in LINE_EDITS:
    lines = load(name).split('\n')
    hits = [i for i, line in enumerate(lines) if line.startswith(prefix)]
    assert len(hits) == 1, f'{name}: 접두사 {prefix!r} 가 한 줄과 맞아야 한다({len(hits)}줄)'
    lines[hits[0]] = new
    texts[name] = '\n'.join(lines)

lines = load(SECTION_FILE).split('\n')
hits = [i for i, line in enumerate(lines) if line == SECTION_TITLE]
assert len(hits) == 1, f'{SECTION_FILE}: 절 제목이 한 곳과 맞아야 한다'
start = hits[0]
end = next(i for i in range(start + 1, len(lines)) if lines[i].startswith('## '))
lines[start:end] = [SECTION_TITLE.replace('(참고)', '(정정됨)'), '', SECTION_BODY, '']
texts[SECTION_FILE] = '\n'.join(lines)

for name, text in texts.items():
    (DOCS / name).write_text(text, encoding='utf-8')
print('정정한 문서:', *texts, sep='\n  ')
```

Run: 위 스크립트를 `/tmp/dlp_docs_edit.py` 로 저장하고 레포 루트에서 `python3 /tmp/dlp_docs_edit.py`
Expected: `정정한 문서:` 아래 `05-ai-dlp-gateway.md`, `02-architecture.md`

- [ ] **Step 3: 거짓 문장이 본문에서 사라졌는지 확인한다**

Run: `grep -n "데이터가 외부 서비스로 나가지 않\|원문은 AI에 그대로 전달되지 않아요\|서버 밖으로 나가지 않는다" docs/05-ai-dlp-gateway.md docs/02-architecture.md`
Expected: 남은 줄은 모두 `~~ … ~~` 취소선 안이거나 `정정`·`폐기`·`쓰지 않는 문구` 표시가 같은 줄에 있다. 취소선 없이 단정하는 줄이 남아 있으면 그 줄을 같은 방식으로 고친다.

- [ ] **Step 4: 사용자 노출 문구에 같은 약속이 남았는지 확인한다 (발견만 기록)**

Run: `grep -rn "먼저 가린\|AI DLP로 개인정보를 보호\|안전하게 가렸어요\|그대로 전달되지 않아요" client/lib server/src/main/resources docs/projectops/store | head`
Expected: 앱·서버·스토어 문구에는 남아 있지 않아야 한다(서비스 원칙 2). 남은 것이 있으면 **고치지 말고** 경로를 이슈 #521 에 남긴다 — 앱 문구 정정은 이 계획의 범위가 아니다. (스토어 한국어 설명의 같은 문장은 계획 6 Task 7 이 레포 원본을 정정하고, 콘솔 값은 사용자가 갱신한다.)

- [ ] **Step 5: 검토 — 문서 소유자가 정정을 확인한다**

이슈 #521 에 정정 diff 를 링크하고 "법적 문구가 아니라 설계 기록 문서의 사실 정정이다. 근거 #377"이라고 적는다. 사용자가 동의하면 다음 Task 로 간다.

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add docs/05-ai-dlp-gateway.md docs/02-architecture.md
```

---

## Task 3: 항목 01 — 국외 이전 동의

**Files:**
- Create: `docs/i18n/legal/01-overseas-transfer.md`

**Interfaces:**
- Consumes: `overseas.txt` · `privacy.txt` 8·9장 · `TextProvider`/`ImageProvider` · `ChildProfileInput` · `RoutineService` · TTS 클라이언트(근거 경로는 시트 안)
- Produces: 법역별 결론표, 필요하면 `overseas` 동의 확정본, 업체별 DPA·보존·학습 사용 확인서, TTS 서버 확인. `launch-gates.md` 의 01 행.

- [ ] **Step 1: 질문지를 만든다**

`docs/i18n/legal/01-overseas-transfer.md`:

````markdown
# 항목 01. 국외 이전 동의

- 상태: 미착수
- 담당(법무): 미정
- 검토 요청일: —
- 영향: 모든 언어 (이용자가 어느 나라에 있든 같은 AI 업체로 전달된다)
- 출시 차단: 예 — `en` 을 열기 전에 닫는다

## 왜 필요한가 (근거)

현재 동의 문서는 한국 개인정보 보호법 기준으로 쓰여 있다. 해외 이용자가 생기면 같은 전송이 **다른 법역의 국외 이전**이 된다.

| 사실 | 근거 |
| --- | --- |
| 카드 글·그림을 만들 때 미국 업체 셋으로 이전된다고 고지한다 — Google LLC · OpenAI, L.L.C. · Features & Labels Inc.(fal) | `server/src/main/resources/consent/overseas.txt` · `server/src/main/resources/consent/privacy.txt` 8·9장 |
| 코드가 실제로 부르는 제공자는 텍스트 Gemini · OpenAI, 이미지 Gemini · OpenAI · FLUX(fal.ai) 다 | `server/src/main/java/com/chuseok22/elumserver/ai/core/TextProvider.java` · `server/src/main/java/com/chuseok22/elumserver/ai/core/ImageProvider.java` |
| 전달 항목: 보호자가 쓴 상황 설명과 추가 질문 답변, 이룸이 이름(별명), 도움 목표 | `server/src/main/java/com/chuseok22/elumserver/ai/core/ChildProfileInput.java` · `overseas.txt` |
| 보호자의 글은 **가공 없이** 전달된다(DLP 폐기 #377) | `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineService.java:134` · `RoutineService.java:197` |
| 동의 문서에 **없는** 전송이 있다 — 이룸이 휴대폰이 카드 문구를 별도 TTS 서버로 보낸다(주소는 `.env` 값이라 코드로 소재지를 알 수 없다) | `client/lib/features/child/data/speech_service.dart` (`RemoteSpeech`) · `client/lib/core/config/app_config.dart` (`ttsBaseUrl`) |
| 광고는 Google 이 직접 수집하고 국외 이전으로 따로 고지한다 | `server/src/main/resources/consent/privacy.txt` 9장 「광고 관련 국외 이전」 |
| 서버 자체는 "직접 운영하며 외부에 맡기지 않는다"고 쓰여 있고 시놀로지 NAS 로 배포한다. 물리적 소재지는 코드로 알 수 없다 | `server/src/main/resources/consent/privacy.txt` 8장 · `.github/workflows/PROJECT-SPRING-CICD.yaml` (`MOUNT_DIR`) |

## 질문

1. (사실 확인 요청) 이용자가 EEA·영국·일본·중국·미국 등에 있을 때, **한국 소재 사업자(Twin-Fang)가 위 미국 업체 셋으로** 보호자 입력을 보내는 데 각 법역에서 필요한 요건은 무엇인가? 동의로 충분한가, 별도 계약 조항(표준계약 등)이나 신고가 필요한가?
2. 현재 `overseas.txt` 의 고지 항목(이전받는 자 · 국가 · 일시·방법 · 항목 · 목적 · 보유기간 · 거부권과 불이익)이 법역별 필수 고지를 충족하는가? 법역마다 문서를 따로 두어야 하는가, 한 문서를 번역하면 되는가?
3. 거부하면 서비스를 쓸 수 없다고 적혀 있다("핵심 기능이라"). 이것이 각 법역에서 유효한 동의 방식인가?
4. 업체별 계약을 확인해 달라: Google Gemini API · OpenAI API · fal.ai 의 ① 데이터 처리 계약(DPA) 체결 여부 ② API 입력의 보존 기간 ③ 모델 학습 사용 여부(유료 키·무료 키에 따라 다른지). **개발 담당이 각 콘솔에서 현재 설정을 캡처해 전달한다.**
5. TTS 서버(`ttsBaseUrl`)는 누가 운영하고 어디에 있는가? 카드 문구(일과 내용)가 전송되는데 처리 위탁 목록에 없다. 목록에 더해야 하는가? (사용자가 운영 주체·소재지를 알려 준다.)
6. 서버가 한국 밖에 있는 이용자의 데이터를 한국에 두는 것 자체가 이용자 측 법역에서 "국외 이전"에 해당하는가?
7. 약관이 게시된 언어마다 이 동의를 **언어별로 따로 받아야** 하는가? 동의 기록에 언어·버전이 남는 것(스펙 4.4)으로 증명이 충분한가?

## 산출물

- [ ] 법역별 결론표(`en` 이 가는 법역, `es` 가 가는 법역, `ja`, `zh`) — 필요한 요건 · 현재 문서가 충족하는지 · 고칠 것
- [ ] 필요하면 언어별 `overseas` 동의 문구 확정본(법무 확정본 — 번역 파일이 아니라 약관 게시본으로 들어간다)
- [ ] 업체별 DPA·보존·학습 사용 확인서(캡처 포함)
- [ ] TTS 서버 소재지와 운영 주체 확인, 처리 위탁 목록 반영 여부 결론

## 답변이 나오면 고칠 곳

| 결론이 | 고칠 곳 |
| --- | --- |
| 문구 수정 | `server/src/main/resources/consent/overseas.txt` · `privacy.txt` 와 클라이언트 번들 기본값(`client/lib/features/auth/domain/consent_documents.dart`), 외부 게시본(`docs/public-pages` 밖 gh-pages) — 약관 4곳 동기화(계획 4) |
| 업체·전송 추가 | 위 문서 + `tool/check_public_pages.py` 가 보는 업체 이름 목록 |

## 답변 기록

| 날짜 | 답변자 | 질문 번호 | 결론 | 근거 문서 |
| --- | --- | --- | --- | --- |
| | | | | |

## 게이트 반영

- [ ] `docs/i18n/legal/launch-gates.md` 의 01 행을 언어별로 채웠다
````

- [ ] **Step 2: 인용한 근거 경로가 실제로 있는지 확인한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: `인용한 경로가 모두 있다`(건너뜀 안내는 있을 수 있다). `❌ 없는 경로` 가 나오면 시트의 경로를 고친다.

- [ ] **Step 3: 개발 담당이 업체 콘솔 캡처를 모은다 (질문 4)**

Google AI Studio·Cloud 의 Gemini API 데이터 처리 설정, OpenAI 대시보드의 데이터 제어 설정, fal.ai 의 데이터 보존 설정을 각각 캡처해 `docs/i18n/legal/evidence/01-<업체>.png` 로 저장한다(비밀 키가 보이지 않게 가린다). TTS 서버(질문 5)의 운영 주체와 소재지는 사용자가 시트의 `답변 기록` 에 직접 적는다.

- [ ] **Step 4: 검토자에게 전달한다 (법무 담당 확정 후)**

시트와 근거 파일, Step 3 캡처를 함께 보낸다. 시트 머리의 `상태` 를 `질문 전달` 로, `검토 요청일` 을 날짜로 바꾼다. 이슈 #521 에 전달 사실을 댓글로 남긴다(`/pro-github`).

- [ ] **Step 5: 답변을 기록한다**

받은 답변을 `답변 기록` 표(날짜 · 답변자 · 질문 번호 · 결론 · 근거 문서)에 옮기고, 산출물 체크박스를 채운다. **구두 답변은 기록으로 치지 않는다** — 문서나 메일 링크를 붙인다. `상태` 를 `답변 받음` 으로 바꾼다.

- [ ] **Step 6: 반영하고 게이트를 채운다**

문구 수정이 나왔으면 반영은 계획 4(약관 네 곳)가 한다 — 시트의 `답변이 나오면 고칠 곳` 표를 이슈에 옮긴다. `launch-gates.md` 의 01 행을 언어별로 `닫힘 <날짜> <확인자>` 또는 법무가 정한 `해당 없음(<사유>)` 으로 바꾸고 시트 `상태` 를 `닫힘` 으로 바꾼다.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/01-overseas-transfer.md docs/i18n/legal/launch-gates.md
```

(Step 3 에서 캡처를 저장했으면 `docs/i18n/legal/evidence/` 의 해당 경로도 명시해 더한다.)

---

## Task 4: 항목 02 — 연령 동의

**Files:**
- Create: `docs/i18n/legal/02-age-consent.md`

**Interfaces:**
- Consumes: `age.txt` · `consent_documents.dart` · `consent_body.dart` · 스토어 타겟층 기록
- Produces: 법역별 보호자 최소 연령표, 연령 확인 문구 확정본, 스토어 타겟층 정정 여부. `launch-gates.md` 의 02 행.

- [ ] **Step 1: 질문지를 만든다**

`docs/i18n/legal/02-age-consent.md`:

````markdown
# 항목 02. 연령 동의

- 상태: 미착수
- 담당(법무): 미정
- 검토 요청일: —
- 영향: 언어별(법역별) — 한국 14세 · EU(GDPR) 16세 · 미국(COPPA) 13세 · 일본
- 출시 차단: 예 — `en` 을 열기 전에 닫는다

## 왜 필요한가 (근거)

| 사실 | 근거 |
| --- | --- |
| 가입 화면에 `만 14세 이상입니다` 체크가 있다. 계정을 만드는 **보호자**의 연령이다. 이룸이 당사자에게는 나이 제한이 없다고 적혀 있다 | `server/src/main/resources/consent/age.txt` · `client/lib/features/auth/domain/consent_documents.dart` (`만 14세 이상입니다`) |
| 이룸이가 만 14세 미만이면 보호자를 법정대리인으로 본다 | `server/src/main/resources/consent/privacy.txt` 0장 |
| 동의 기준은 한 가지(14세)이고 국가·언어별로 갈리지 않는다 | `client/lib/features/auth/domain/consent_body.dart` |
| Play 타겟층이 `13~15세, 16~17세, 만 18세 이상` 으로 신고돼 있다 | `docs/projectops/store/20260921_스토어_문구_원본.md` 「콘솔에 실제로 넣은 값」 |
| 스펙의 열린 질문: 만 14세 동의 기준을 국가별로 바꿔야 하는가 | `docs/superpowers/specs/2026-10-02-multi-language-design.md` 8장 |

작성자가 알고 있는 바(**확인 필요**): GDPR 8조는 정보사회서비스에서 아동의 동의 연령을 16세로 두고 회원국이 13세까지 낮출 수 있다. 미국 COPPA 는 13세 미만 아동 대상 서비스·실제로 아는 경우에 적용된다. 일본 개인정보보호법에는 연령 명문 기준이 없고 지침에서 정한다. 중국 개인정보보호법은 14세 미만의 정보를 민감정보로 다룬다. **이 중 어느 것도 사실로 쓰지 않는다.**

## 질문

1. 계정을 만드는 **보호자**에게 요구할 최소 연령은 법역별로 몇 세인가? 가장 엄격한 값(예: 16세)으로 통일해도 서비스 구조에 문제가 없는가(한국의 14~15세 보호자는 사실상 없다)?
2. 이 앱에서 개인정보의 주체는 **이룸이**(별명 · 도움 목표 · 일과)이고, 계정 주체는 보호자다. COPPA · GDPR 8조 같은 "아동 동의" 규정은 누구를 기준으로 적용되는가? 이룸이는 20대 성인일 수도 있고 만 14세 미만일 수도 있다.
3. `만 14세 이상입니다` 문구(자기 신고 체크)가 각 법역에서 연령 확인으로 충분한가? 문구를 법역별로 바꿔야 한다면 확정 문구는?
4. 타겟층을 13~15세 포함으로 신고한 것이 스토어 정책(Play 가족 정책, Apple 아동 관련 규정)과 이 연령 기준에 모순이 없는가? 이 앱은 아동 카테고리가 아니라고 심사 노트에 적어 두었다(`client/ios/fastlane/review_notes.txt`).
5. 광고(AdMob)를 보호자 화면에 띄울 때 연령 관련 태그(아동 대상 처리 · 동의 연령 미만 처리)가 필요한가? (항목 05 와 함께 답한다.)

## 산출물

- [ ] 법역별 보호자 최소 연령표(한국 · EEA 각국 대표 · 영국 · 미국 · 일본 · 중국 · 스페인/멕시코 중 출시 대상)
- [ ] 연령 확인 문구 확정본(법무 확정본)과 적용 방식(전 법역 통일 / 법역별)
- [ ] 스토어 타겟층 신고 정정 여부(항목 06 과 연결)

## 답변이 나오면 고칠 곳

| 결론이 | 고칠 곳 |
| --- | --- |
| 기준 연령 변경 | `age.txt` · `consent_documents.dart` · 가입 화면 문구 · 앱 심사 노트 · 스토어 연령 등급(항목 06) |
| 법역별 분기 필요 | 스펙 4.4 의 "지역 축" 이 필요하다는 결론이다 — 항목 09 로 올린다(키 구조 변경은 계획 4 에 요청) |

## 답변 기록

| 날짜 | 답변자 | 질문 번호 | 결론 | 근거 문서 |
| --- | --- | --- | --- | --- |
| | | | | |

## 게이트 반영

- [ ] `docs/i18n/legal/launch-gates.md` 의 02 행을 언어별로 채웠다
````

- [ ] **Step 2: 근거 경로를 확인한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: `인용한 경로가 모두 있다`

- [ ] **Step 3: 검토자에게 전달한다 (법무 담당 확정 후)**

시트 `상태` → `질문 전달`, 날짜 기입, 이슈 댓글. 항목 05(광고 연령 태그)와 같은 검토자에게 한 번에 보낸다(질문 5 가 겹친다).

- [ ] **Step 4: 답변을 기록한다**

`답변 기록` 표를 채우고 `상태` → `답변 받음`. 법역별 최소 연령표를 시트 `산출물` 아래에 붙인다. **제품 결정이 필요한 선택**(전 법역 16세 통일 / 법역별 분기)은 검토자의 선택지를 그대로 옮기고 사용자 결정을 따로 적는다.

- [ ] **Step 5: 반영하고 게이트를 채운다**

법역별 분기가 필요하다는 답이면 **항목 09 의 지역 축 결론에 올린다**(구조 변경을 이 계획이 하지 않는다). 문구 변경이면 약관 네 곳(계획 4)에 요청한다. `launch-gates.md` 의 02 행을 채우고 시트 `상태` → `닫힘`.

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/02-age-consent.md docs/i18n/legal/launch-gates.md
```

---

## Task 5: 항목 03 — 자유 입력과 사진의 특수범주

**Files:**
- Create: `docs/i18n/legal/03-special-category.md`

**Interfaces:**
- Consumes: `privacy.txt` 2장 · `support_goal.dart` · `RoutineService` · `RoutineStepPhotoService` · 서비스 원칙 1·5
- Produces: 법역별 특수범주·요배려정보 결론, 입력 단계 경고·동의 문구·영향평가 필요 여부, 방침에 사진을 더할지 결론. `launch-gates.md` 의 03 행.

이 항목은 **서비스 원칙 1("진단명 수집 금지")이 입력 가능성까지 막아 주는지**를 묻는다. 결론이 "입력 단계 경고 필요"로 나오면 구현은 새 기능 이슈다(원문을 저장하지 않는 방식이어야 한다 — 원칙 5).

- [ ] **Step 1: 질문지를 만든다**

`docs/i18n/legal/03-special-category.md`:

````markdown
# 항목 03. 자유 입력과 사진의 특수범주

- 상태: 미착수
- 담당(법무): 미정
- 검토 요청일: —
- 영향: 모든 언어 (GDPR 9조 특수범주, 일본 APPI 요배려개인정보, 한국 민감정보)
- 출시 차단: 예 — `en` 을 열기 전에 닫는다

## 왜 필요한가 (근거)

서비스 원칙 1은 "진단명 · 장애 유형을 **수집하지 않는다**"이다. 그런데 서비스의 사용자 자체가 발달장애 당사자이고, 입력은 자유 텍스트다. **수집하지 않는 것과 입력될 수 있는 것은 다르다.**

| 사실 | 근거 |
| --- | --- |
| 진단명·장애 유형·등급을 수집하지 않는다고 방침에 적혀 있고, 개인화는 도움 목표 네 개로만 한다 | `server/src/main/resources/consent/privacy.txt` 2장 · `client/lib/features/onboarding/domain/support_goal.dart` |
| 도움 목표는 `해야 할 일을 순서대로 이해해요` · `필요한 준비물을 스스로 챙겨요` · `새로운 상황을 미리 준비해요` · `혼자 끝까지 해내는 경험을 만들어요` — 인지·생활 지원 성격이 드러난다 | `client/lib/features/onboarding/domain/support_goal.dart` |
| 상황 설명·추가 질문 답변은 자유 입력이고 **가공 없이** 외부 AI 업체로 간다. 방침은 "개인정보를 적지 말아 달라"고 안내할 뿐이다 | `server/src/main/resources/consent/overseas.txt` · `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineService.java:134` |
| 원문은 감사 로그에 저장하지 않는다(서비스 원칙 5) | 루트 `CLAUDE.md` 서비스 원칙 |
| 보호자가 카메라·사진 보관함의 사진을 카드 그림으로 올린다. 서버가 재인코딩해 로컬 디스크에 저장한다 | `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineStepPhotoService.java` · `server/src/main/java/com/chuseok22/elumserver/routine/infrastructure/storage/LocalFileRoutineImageStorage.java` · `client/ios/Runner/Info.plist` (`NSCameraUsageDescription`) |
| 그런데 방침 수집 항목에는 사진이 없고 "사진첩·연락처 접근 정보는 수집하지 않습니다" 라고만 적혀 있다 | `server/src/main/resources/consent/privacy.txt` 1·2장 |

## 질문

1. 이 서비스가 발달장애 당사자를 위한 것이라는 사실, 그리고 도움 목표 선택(인지·생활 지원)이 **건강 관련 정보(GDPR 9조)** · **요배려개인정보(APPI)** · **한국 민감정보** 로 분류될 위험이 있는가? 위험이 있다면 어떤 요건(명시적 동의 · 영향평가)이 붙는가?
2. 보호자가 자유 입력에 진단명을 적을 수 있다. 이를 가공 없이 미국 AI 업체에 보내는 것에 특수범주 규정이 적용되는가? 현재의 "적지 말아 주세요" 안내로 충분한가, **입력 단계의 경고·차단**이 필요한가? (경고를 위해 서버가 입력을 검사해도 원문을 저장하지 않는다 — 서비스 원칙 5 와 충돌하지 않는다.)
3. 한국 개인정보 보호법 기준으로도 같은 질문: 현재 동의서(`privacy.txt`)는 이 위험을 다루는가?
4. 사진 업로드가 방침에 빠져 있다. 방침의 수집 항목에 사진을 명시해야 하는가? 사진에 얼굴·건강 상태가 담길 수 있다. 식별 목적의 생체정보 처리는 아니라고 보는데(얼굴 인식을 하지 않는다), 법무가 확인해 달라.
5. 영향평가(DPIA)가 필요한가? 필요하면 누가 · 언제까지 만드는가?
6. 이 답이 **언어별로 달라지는가**(예: EEA 에서는 필요하고 일본에서는 다른 요건이 붙는가)?

## 산출물

- [ ] 특수범주·요배려정보 해당 여부 결론(법역별)
- [ ] 필요한 경우: 입력 안내·경고 문구 확정본, 동의 문구 확정본, 영향평가 요약
- [ ] 방침 수집 항목에 사진을 더할지 결론과 문구

## 답변이 나오면 고칠 곳

| 결론이 | 고칠 곳 |
| --- | --- |
| 입력 단계 경고 필요 | 일과 입력 화면(`client/lib/features/guardian/presentation/routine_input_screen.dart`) — 서버로 원문을 보내거나 저장하지 않는 방식이어야 한다 |
| 방침 수정 | `privacy.txt` 1·2장 + 4곳 동기화(계획 4) + 게시본 |
| 도움 목표 문구가 문제 | `support_goal.dart` 와 서버 `SupportGoal.java` 를 함께 — 디자이너(예람)와 협의 대상 |

## 답변 기록

| 날짜 | 답변자 | 질문 번호 | 결론 | 근거 문서 |
| --- | --- | --- | --- | --- |
| | | | | |

## 게이트 반영

- [ ] `docs/i18n/legal/launch-gates.md` 의 03 행을 언어별로 채웠다
````

- [ ] **Step 2: 근거 경로를 확인한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: `인용한 경로가 모두 있다`

- [ ] **Step 3: 개발 담당이 사진 처리 사실을 한 문단으로 적어 시트에 붙인다**

질문 4 의 답은 사실에 달려 있다. 아래를 코드에서 확인해 시트 `산출물` 위에 `사실 확인(개발 담당, <날짜>)` 으로 붙인다: 업로드 크기·형식 제한과 재인코딩 여부(`server/src/main/java/com/chuseok22/elumserver/routine/core/RoutinePhotoProcessor.java`), 저장 위치(`LocalFileRoutineImageStorage.java` — 서버 로컬 디스크), 삭제 시점(카드·일과·회원 탈퇴 시 파일이 지워지는지 — `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineStepPhotoService.java` 와 회원 탈퇴 경로), 얼굴 인식 등 사진 내용 분석이 **없다**는 것.

- [ ] **Step 4: 검토자에게 전달한다 (법무 담당 확정 후)**

시트 + Step 3 사실 확인을 보낸다. 시트 `상태` → `질문 전달`, 이슈 댓글.

- [ ] **Step 5: 답변을 기록한다**

`답변 기록` 표를 채우고 `상태` → `답변 받음`. 결론이 "특수범주 해당"이면 시트 `산출물` 의 동의·경고 문구 확정본을 받는다.

- [ ] **Step 6: 반영하고 게이트를 채운다**

방침에 사진 수집을 더하는 결론이면 약관 네 곳(계획 4)에 요청한다. 입력 경고가 필요하다는 결론이면 새 기능 이슈를 올린다(`/pro-github`) — **이 계획에서 구현하지 않는다.** `launch-gates.md` 의 03 행을 채우고 시트 `상태` → `닫힘`.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/03-special-category.md docs/i18n/legal/launch-gates.md
```

---

## Task 6: 항목 04 — 법정대리인 · 성인 후견 구조

**Files:**
- Create: `docs/i18n/legal/04-guardianship.md`

**Interfaces:**
- Consumes: `privacy.txt` 0장 · `consent_body.dart` · `consent_documents.dart` · 다중 보호자 설계
- Produces: 갈래별·법역별 유효성 표, **법적 용어 확정 목록**(번역가가 쓴다), 필요하면 방침 0장·동의 문구 확정본. `launch-gates.md` 의 04 행.

- [ ] **Step 1: 질문지를 만든다**

`docs/i18n/legal/04-guardianship.md`:

````markdown
# 항목 04. 법정대리인 · 성인 후견 구조

- 상태: 미착수
- 담당(법무): 미정
- 검토 요청일: —
- 영향: 언어별(법역별) — 번역할 때 "법정대리인"을 어떤 법적 용어로 옮기는가
- 출시 차단: 예 — `en` 을 열기 전에 닫는다

## 왜 필요한가 (근거)

방침 0장은 보호자가 이룸이 정보를 대신 입력할 수 있는 근거를 **세 갈래**로 적는다. 한국 법의 용어와 효력을 전제로 쓴 문장이다.

| 사실 | 근거 |
| --- | --- |
| ① 이룸이가 만 14세 미만 — 법정대리인(부모 또는 후견인). 이 동의가 개인정보 보호법의 법정대리인 동의를 갈음한다 | `server/src/main/resources/consent/privacy.txt` 0장 |
| ② 이룸이가 성인이고 후견이 개시된 경우 — 법원이 선임한 성년후견인 또는 한정후견인 | 같은 문서 |
| ③ 이룸이가 성인이고 후견이 개시되지 않은 경우 — **이룸이 본인의 동의를 받아** 보호자가 대신 입력한다. 이 경우 보호자는 법정대리인이 아니다 | 같은 문서 |
| 어느 갈래인지는 **보호자가 스스로 선언**한다(시스템이 검증하지 않는다) | `client/lib/features/auth/domain/consent_body.dart` · `client/lib/features/auth/domain/consent_documents.dart` |
| 보호자는 가족·복지사를 포함해 여럿이고 이룸이 정보를 모두 고칠 수 있다 | `docs/superpowers/specs/2026-09-23-multi-guardian-design.md` · `server/src/main/resources/consent/privacy.txt` 0장 |
| 이룸이 당사자는 계정을 만들지 않고 직접 로그인하지 않는다 | `server/src/main/resources/consent/terms.txt` 제3조 |

작성자가 알고 있는 바(**확인 필요**): 영어권의 legal guardian · conservator, 일본의 成年後見人 · 保佐人 · 補助人(한국의 한정후견인과 정확히 대응하지 않을 수 있다), 중국의 监护人, 스페인의 tutor · curador(제도가 개편돼 지원 제도 중심이다). 용어가 법역마다 효력 범위가 다르다.

## 질문

1. 세 갈래 구조가 각 법역(`en`: 미국·영국 등 · `es`: 스페인·중남미 · `ja` · `zh`)에서 유효한가? 갈래 ③(성인 본인 동의 + 대신 입력)은 성인의 자기결정 존중이라는 취지인데, 법역에 따라 **본인이 의사능력을 갖췄다는 확인**이 더 필요한가?
2. "법정대리인" · "성년후견인" · "한정후견인" 을 각 언어로 어떻게 옮겨야 법적 의미가 맞는가? 번역가가 임의로 옮기지 않도록 **확정 용어 목록**을 달라(용어집의 "법적 문구는 번역하지 않는다" 규칙과 연결).
3. 어느 갈래인지를 보호자가 자기 신고하는 구조의 책임 소재 — 신고가 사실과 달랐을 때 서비스 약관상 책임 분담 문구가 필요한가?
4. 복지사 같은 **법정대리인이 아닌 보호자**가 이룸이 정보를 입력할 때의 근거는 무엇인가? 갈래 ③ 으로 충분한가, 소속 기관 위탁 구조가 따로 필요한가?
5. 위 구조가 언어별 동의 화면(`age` 와 `privacy` 의 0장)에 **어떤 순서·문구로** 나와야 하는가?

## 산출물

- [ ] 갈래별 · 법역별 유효성 표(① ② ③ × en es ja zh)
- [ ] 법적 용어 확정 목록(용어집 연결: 번역가는 이 목록만 쓴다)
- [ ] 필요하면 방침 0장·동의 문구 확정본(법무 확정본)

## 답변이 나오면 고칠 곳

| 결론이 | 고칠 곳 |
| --- | --- |
| 문구 수정 | `privacy.txt` 0장과 클라이언트 번들(`consent_documents.dart`) 외 4곳(계획 4) |
| 용어 확정 | `docs/i18n/glossary.md` 에 "법적 용어" 줄을 더한다(법무 확정본만 채운다) |

## 답변 기록

| 날짜 | 답변자 | 질문 번호 | 결론 | 근거 문서 |
| --- | --- | --- | --- | --- |
| | | | | |

## 게이트 반영

- [ ] `docs/i18n/legal/launch-gates.md` 의 04 행을 언어별로 채웠다
````

- [ ] **Step 2: 근거 경로를 확인한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: `인용한 경로가 모두 있다`

- [ ] **Step 3: 검토자에게 전달한다 (법무 담당 확정 후)**

시트 `상태` → `질문 전달`, 이슈 댓글. 언어마다 법역 전문가가 다르면 언어별로 나눠 보내고 질문 2 의 확정 용어 목록을 언어별로 받는다.

- [ ] **Step 4: 답변을 기록한다**

`답변 기록` 을 채우고 `상태` → `답변 받음`. **법적 용어 확정 목록**은 시트 `산출물` 아래에 표(ko · en · es · ja · zh)로 붙인다.

- [ ] **Step 5: 용어 목록을 용어집에 연결한다**

`docs/i18n/glossary.md`(계획 5)가 있으면 용어표에 "법적 용어" 줄(법정대리인 · 성년후견인 · 한정후견인)을 더하고 상태를 `확정`, 번역 칸은 **법무 확정본 그대로** 채운다. 용어집이 아직 없으면 이 Step 은 계획 5 Task 9 뒤로 미루고 이슈에 적는다.

- [ ] **Step 6: 반영하고 게이트를 채운다**

문구 변경은 계획 4 에 요청한다. `launch-gates.md` 의 04 행을 채우고 시트 `상태` → `닫힘`.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/04-guardianship.md docs/i18n/legal/launch-gates.md
```

(Step 5 에서 용어집을 고쳤으면 `docs/i18n/glossary.md` 도 명시해 더한다.)

---

## Task 7: 항목 05 — 광고 ID · ATT · EU 동의(UMP)

**Files:**
- Create: `docs/i18n/legal/05-ads-consent.md`

**Interfaces:**
- Consumes: `ad_consent.dart` · `ad_sdk.dart` · `ad_gate.dart` · `privacy.txt` 1·8·9장 · iOS 제출 정보
- Produces: 지역별 광고 정책표, UMP 도입 필요 여부 결론, 방침 광고 절 수정안. `launch-gates.md` 의 05 행.

**이 항목이 닫히지 않으면 `en`·`es` 를 EEA·영국이 포함된 법역으로 열지 않는다.** UMP 도입은 별도 기능 이슈다(이 계획이 구현하지 않는다). 도입 전 선택지는 해당 지역에서 광고를 끄는 것이다.

- [ ] **Step 1: 질문지를 만든다**

`docs/i18n/legal/05-ads-consent.md`:

````markdown
# 항목 05. 광고 ID · ATT · EU 동의(UMP)

- 상태: 미착수
- 담당(법무): 미정
- 검토 요청일: —
- 영향: `en` · `es` 가 EEA·영국으로 나가는 경우가 가장 크다. `ja` · `zh` 도 확인한다
- 출시 차단: 예 — 광고가 켜진 채 해당 지역으로 열기 전에 닫는다

## 왜 필요한가 (근거)

보호자 화면에는 Google AdMob 광고가 뜬다. 지금 동의 장치는 **iOS 의 ATT 하나**다.

| 사실 | 근거 |
| --- | --- |
| 앱을 열면 ATT 팝업을 한 번 띄우고, 거부하면 비개인화 광고로 요청한다. **Android 는 ATT 가 없어 개인화 기본이다** | `client/lib/core/ads/ad_consent.dart` |
| 광고 SDK 초기화에는 콘텐츠 등급(`pg`)만 있다. 아동 대상 처리·동의 연령 미만 처리 태그는 없다 | `client/lib/core/ads/ad_sdk.dart` |
| 사용자 메시징 플랫폼(UMP) · TCF 동의 코드가 앱에 **없다** | `client/lib/core` 아래 `ConsentInformation`·`UserMessagingPlatform` 검색 결과 없음 |
| 방침이 광고 항목(광고 식별자 · IP · 기기·앱 정보 · 광고 이용 정보 · 진단 정보)과 광고 관련 국외 이전을 적는다 | `server/src/main/resources/consent/privacy.txt` 1·8·9장 |
| 약관에 광고 조항(제5조의2)이 있다 | `server/src/main/resources/consent/terms.txt` |
| 이룸이 전용 휴대폰은 광고를 보여 주지 않는다 | `client/lib/core/ads/ad_gate.dart` · `server/src/main/resources/consent/privacy.txt` 8장 |
| iOS 앱이 IDFA 사용·광고 게재로 신고하고 ATT 문구를 가진다 | `client/ios/fastlane/Fastfile` (`submission_information`) · `client/ios/Runner/Info.plist` (`NSUserTrackingUsageDescription`) |

작성자가 알고 있는 바(**확인 필요**): EEA·영국·스위스 사용자에게 AdMob 광고를 보이려면 Google 의 EU 사용자 동의 정책에 따라 TCF 호환 동의 관리 플랫폼으로 동의를 받아야 한다. 이 앱에는 그 장치가 없다.

## 질문

1. `en`·`es` 를 EEA·영국에서 쓸 수 있게 열면 광고가 나가기 전에 **동의 관리 플랫폼(UMP) 동의**가 법적으로 필요한가? 필요하다면 선택지는 ① UMP 도입 ② EEA·영국에서 광고를 끔(지역 판정 또는 스토어 국가 제한) 중 무엇이 가능한가?
2. 비개인화 광고 요청이어도 기기 식별자 접근에 동의가 필요한 법역이 있는가(ePrivacy)?
3. 미국 주법(캘리포니아 등)과 COPPA 상 광고 SDK 에 아동 대상 처리 · 동의 연령 미만 처리를 지정해야 하는가? 타겟층에 13~15세가 포함돼 있다(항목 02).
4. 일본·중국에서 광고 SDK 가 이용자 정보를 외부로 보내는 것에 별도 통지·공표 의무가 있는가? 중국 본토에서 AdMob 이 동작하는가(서비스 가능 여부는 법무가 아니라 제품 확인 사항이다 — 개발 담당이 확인).
5. `NSUserTrackingUsageDescription` 문구의 번역은 법적 정확성 검토가 필요한가? ATT 문구는 계획 6 에서 언어별 `InfoPlist.strings` 로 번역된다.
6. 방침의 광고 절(수집 항목 · 거부 방법 · 국외 이전)이 법역별로 달라야 하는가?

## 산출물

- [ ] 지역별 광고 정책표(광고 노출 · 비노출 · 동의 필요) — **제품 결정이 필요한 선택지는 `제품 결정` 칸에 사용자 결정으로 남긴다**
- [ ] UMP 도입 필요 여부 결론(필요하면 별도 기능 이슈로 올린다 — 이 계획의 범위 밖)
- [ ] 방침 광고 절 수정안(법무 확정본)

## 답변이 나오면 고칠 곳

| 결론이 | 고칠 곳 |
| --- | --- |
| UMP 도입 | 새 이슈(클라이언트 광고 기능). 이 계획은 결론만 기록한다. 도입 전에는 해당 지역에서 광고를 켜지 않는다 |
| 지역별 광고 끔 | `client/lib/core/ads/ad_gate.dart` 의 노출 조건 — 서버 설정이나 지역 판정 방식은 별도 설계 |
| 방침 수정 | `privacy.txt` 1·8·9장 + 4곳 동기화(계획 4) |

## 답변 기록

| 날짜 | 답변자 | 질문 번호 | 결론 | 근거 문서 |
| --- | --- | --- | --- | --- |
| | | | | |

## 게이트 반영

- [ ] `docs/i18n/legal/launch-gates.md` 의 05 행을 언어별로 채웠다
````

- [ ] **Step 2: 근거 경로를 확인한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: `인용한 경로가 모두 있다`

- [ ] **Step 3: 개발 담당이 AdMob 서비스 가능 지역을 확인한다 (질문 4 의 제품 확인 부분)**

AdMob 콘솔에서 앱이 광고를 받을 수 있는 지역과 중국 본토에서의 동작 여부를 확인해 시트에 `사실 확인(개발 담당, <날짜>)` 으로 붙인다. 계정·앱 ID 는 시트에 적지 않는다.

- [ ] **Step 4: 검토자에게 전달한다 (법무 담당 확정 후)**

항목 02 와 같은 검토자에게 보낸다(광고 연령 태그 질문이 겹친다). 시트 `상태` → `질문 전달`, 이슈 댓글.

- [ ] **Step 5: 답변을 기록한다**

`답변 기록` 을 채우고 `상태` → `답변 받음`. 지역별 광고 정책표의 **제품 결정 칸**(어느 지역에서 광고를 끌지, UMP 를 도입할지)은 사용자 결정으로 따로 적는다.

- [ ] **Step 6: 반영하고 게이트를 채운다**

UMP 도입이나 지역별 광고 끔이 결론이면 새 기능 이슈를 올린다. 방침 광고 절 수정은 계획 4 에 요청한다. `launch-gates.md` 의 05 행을 언어별로 채운다 — 광고를 끈 지역만 가는 언어는 `해당 없음(광고 비노출 지역)` 을 **법무가 그렇다고 답한 경우에만** 쓴다. 시트 `상태` → `닫힘`.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/05-ads-consent.md docs/i18n/legal/launch-gates.md
```

---

## Task 8: 항목 06 — 스토어 신고서 · 배포 국가

**Files:**
- Create: `docs/i18n/legal/06-store-declarations.md`

**Interfaces:**
- Consumes: `20260921_스토어_문구_원본.md`(콘솔 기록) · 광고 코드 · iOS 제출 정보 · 사진 업로드
- Produces: 신고서 정정표, 승인된 배포 국가 목록, 등급 재설문 필요 여부. `launch-gates.md` 의 06 행.

콘솔(App Store Connect · Play Console)은 **사용자만 고친다.** 이 계획은 정정표만 만든다. 배포 국가 줄이기와 신고 정정은 앱 배포가 아니라 콘솔 설정이지만, 심사로 이어질 수 있으므로 사용자가 직접 한다.

- [ ] **Step 1: 질문지를 만든다**

`docs/i18n/legal/06-store-declarations.md`:

````markdown
# 항목 06. 스토어 신고서 · 배포 국가

- 상태: 미착수
- 담당(법무): 미정 (콘솔 값은 **사용자가 직접** 확인·수정한다)
- 검토 요청일: —
- 영향: 모든 언어 — 새 언어는 새 국가의 스토어 노출을 뜻한다
- 출시 차단: 예 — 언어별 스토어 문구를 올리기 전에 닫는다

## 왜 필요한가 (근거)

스토어 콘솔 신고는 **2026-09-21 기록**이고, 그 뒤 광고(AdMob · ATT)와 사진 업로드가 들어왔다. 신고와 현재 앱이 어긋난 채 새 국가로 나가면 같은 문제가 더 넓게 퍼진다.

| 사실 | 근거 |
| --- | --- |
| Play 신고 기록: **광고 없음 · 광고 ID 사용 안 함**, 데이터 보안 6종 수집 | `docs/projectops/store/20260921_스토어_문구_원본.md` 「콘솔에 실제로 넣은 값」 |
| 지금 앱은 광고 ID 를 쓴다(AdMob · ATT) | `client/lib/core/ads/ad_sdk.dart` · `client/android/app/src/main/AndroidManifest.xml` (`AD_ID`) · `server/src/main/resources/consent/privacy.txt` 1장 |
| App Store 신고: App Privacy 6종 `추적 안 함`, **배포 175개국** | `docs/projectops/store/20260921_스토어_문구_원본.md` |
| 지금 IDFA 사용·광고 게재로 제출한다 | `client/ios/fastlane/Fastfile` (`add_id_info_uses_idfa: true`) |
| Play 타겟층 13~15 · 16~17 · 18+, 연령 등급 설문 완료(ASC 9+) | `docs/projectops/store/20260921_스토어_문구_원본.md` |
| EU DSA 는 **비거래자**로 선언했다 | 같은 문서 |
| 사진 업로드(카드 그림)가 새로 생겼다 | `server/src/main/java/com/chuseok22/elumserver/routine/application/service/RoutineStepPhotoService.java` |

## 질문

1. 현재 앱(AdMob · ATT · 사진 업로드 · 외부 AI 전송)에 비춰 **Play 데이터 보안·광고 선언**과 **App Store App Privacy · 추적** 신고가 정확한가? 어긋나는 칸을 알려 달라. (콘솔은 사용자가 고친다.)
2. 새 언어로 새 국가를 열면 **등급 설문(IARC · 지역 등급)** 을 다시 해야 하는가? 앱이 생성형 AI 로 콘텐츠를 만든다는 답변이 일부 법역의 규정(예: 생성물 표시 의무)에 걸리는가?
3. App Store 배포 국가를 지금 175개국으로 둔 채 언어만 늘려도 되는가? **배포 국가를 법무가 승인한 목록으로 줄여야 하는가?** 특히 중국 본토 배포가 포함돼 있다면 앱 등록(ICP 등)이 필요한지 확인해 달라. (포함 여부는 사용자가 ASC 에서 확인한다.)
4. EU DSA 비거래자 선언이 광고 수익이 있는 지금도 유지되는가? 유료 요금제(크레딧)가 생기면 달라지는가?
5. 스토어 이용약관·개인정보 URL 필드를 언어별로 채울 때(항목 08) 신고서와의 일치 요건이 있는가?

## 산출물

- [ ] 신고서 정정표(콘솔 · 칸 · 현재 값 · 맞는 값)
- [ ] 승인된 배포 국가 목록(언어별) — 사용자가 ASC · Play 에 반영
- [ ] 등급 재설문 필요 여부와 그 결과

## 답변이 나오면 고칠 곳

| 결론이 | 고칠 곳 |
| --- | --- |
| 콘솔 값 정정 | App Store Connect · Play Console (사용자). 끝나면 `docs/projectops/store/20260921_스토어_문구_원본.md` 「콘솔에 실제로 넣은 값」에 날짜와 함께 갱신 |
| 배포 국가 축소 | ASC · Play 의 국가 설정(사용자) |

## 답변 기록

| 날짜 | 답변자 | 질문 번호 | 결론 | 근거 문서 |
| --- | --- | --- | --- | --- |
| | | | | |

## 게이트 반영

- [ ] `docs/i18n/legal/launch-gates.md` 의 06 행을 언어별로 채웠다
````

- [ ] **Step 2: 근거 경로를 확인한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: `인용한 경로가 모두 있다`

- [ ] **Step 3: 사용자가 콘솔의 현재 값을 시트에 붙인다**

Play Console 의 데이터 보안·광고·타겟층 신고 화면과 App Store Connect 의 App Privacy·배포 국가 화면을 캡처해 `docs/i18n/legal/evidence/06-*.png` 로 둔다. **중국 본토가 배포 국가에 포함돼 있는지**(질문 3)를 시트에 한 줄로 적는다. 레포 문서의 기록이 낡았을 수 있으므로 콘솔의 현재 값이 기준이다.

- [ ] **Step 4: 검토자에게 전달한다 (법무 담당 확정 후)**

시트 + 캡처를 보낸다. 시트 `상태` → `질문 전달`, 이슈 댓글.

- [ ] **Step 5: 답변을 기록한다**

`답변 기록` 을 채우고 `상태` → `답변 받음`. 신고서 정정표를 시트에 붙인다.

- [ ] **Step 6: 사용자가 콘솔을 고치고 기록을 갱신한다**

정정표대로 콘솔을 고친 뒤 `docs/projectops/store/20260921_스토어_문구_원본.md` 의 「콘솔에 실제로 넣은 값」에 **날짜와 함께** 변경을 적는다. `launch-gates.md` 의 06 행을 채우고 시트 `상태` → `닫힘`.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/06-store-declarations.md docs/i18n/legal/launch-gates.md docs/projectops/store/20260921_스토어_문구_원본.md
```

(Step 3 의 캡처를 저장했으면 `docs/i18n/legal/evidence/` 경로도 명시해 더한다.)

---

## Task 9: 항목 07 — 약관 준거법 · 관할 · 우선 언어

**Files:**
- Create: `docs/i18n/legal/07-terms-governing-law.md`

**Interfaces:**
- Consumes: `terms.txt`(조항 목록) · 스펙 4.4·4.5
- Produces: 준거법·관할·우선 언어 조항 확정본, 불공정 조항 수정안, **번역 금지 문구 목록**(제5조의3 등). `launch-gates.md` 의 07 행.

번역 금지 문구 목록은 번역 작업 절차(`docs/i18n/translation-workflow.md`)의 검수 체크리스트에 더한다 — 이 항목이 닫히면 그 파일에 한 줄을 더하는 것이 이 Task 의 코드 쪽 후속이다.

- [ ] **Step 1: 질문지를 만든다**

`docs/i18n/legal/07-terms-governing-law.md`:

````markdown
# 항목 07. 약관 준거법 · 관할 · 우선 언어

- 상태: 미착수
- 담당(법무): 미정
- 검토 요청일: —
- 영향: 언어별 약관 게시본 — 약관은 그 언어의 법무 확인본이 있어야 그 언어를 연다
- 출시 차단: 예 — `en` 을 열기 전에 닫는다

## 왜 필요한가 (근거)

현재 이용약관에는 **준거법 · 관할 · 분쟁 해결 조항이 없다.** 한국어 사용자만 있을 때는 묵시적으로 한국법이었지만, 다른 법역의 이용자가 생기면 어느 나라 법으로 읽을지가 비어 있다.

| 사실 | 근거 |
| --- | --- |
| 이용약관은 제1~7조와 부칙뿐이다. 준거법 · 관할 · 분쟁 해결 · 소비자 권리 조항이 없다 | `server/src/main/resources/consent/terms.txt` |
| 서비스 변경·중단(제5조), 무료 서비스 중단에 보상 없음, 면책(제6조), AI 결과 면책이 있다 | 같은 문서 제5조 · 제6조 |
| 사업자는 Twin-Fang(한국), 문의 주소는 개인 메일이다 | `terms.txt` 제1조 · 제7조 |
| 그림 일부는 CC BY-SA 4.0 라이선스의 Mulberry Symbols 이고, **출처 표기 문구가 약관에 박혀 있다**(제5조의3) | `terms.txt` 제5조의3 |
| 약관은 서버 관리(관리자 화면) + 번들 기본값이고 `(약관 키, 언어)` 로 언어별 행을 둔다. **언어마다 게시본이 있어야 그 언어를 연다** | `docs/superpowers/specs/2026-10-02-multi-language-design.md` 4.4 · 4.5 |
| 언어와 법역은 다르다(스페인어는 스페인·멕시코, 영어는 미국·영국) | 같은 문서 4.4 |

## 질문

1. 한국 사업자가 해외 이용자에게 제공하는 약관에 **준거법(대한민국법)과 전속 관할**을 지정할 수 있는가? 소비자 보호 강행규정 때문에 지정이 무효이거나 제한되는 법역(EU · 영국 · 일본 · 중국)은 어디인가?
2. 서비스 변경·중단(제5조), 면책·책임 제한(제6조), 일방적 약관 변경이 각 법역의 소비자계약 불공정 조항 규제에 걸릴 위험이 있는가? 걸린다면 법역별 수정 문구는?
3. 언어별 약관이 서로 어긋날 때 **우선하는 언어** 조항이 필요한가(예: 한국어 원본 우선)? 필요하면 확정 문구는?
4. 분쟁 해결 · 소비자 철회권 · 연락처(개인 메일) 표기에 법역별 필수 사항이 있는가?
5. AI 생성물 면책(제6조 2항)이 각 법역에서 유효한가? 생성형 AI 관련 고지 의무가 있는가?
6. **제5조의3(그림 출처)은 번역하면 안 되는 문구인가?** 라이선스 고지는 원문(영어) 그대로 유지하고 한국어·번역 문장은 그 옆에 두는 구성이 맞는지 확인해 달라. 번역가는 이 조항을 임의로 옮기지 않는다.

## 산출물

- [ ] 준거법 · 관할 · 우선 언어 조항 확정본(법무 확정본, 언어별)
- [ ] 불공정 조항 위험 조항의 법역별 수정안
- [ ] 번역 금지 문구 목록(제5조의3 등) — 번역 작업 절차의 검수 체크리스트에 더한다

## 답변이 나오면 고칠 곳

| 결론이 | 고칠 곳 |
| --- | --- |
| 조항 추가·수정 | `terms.txt` + 클라이언트 번들(`consent_documents.dart`) + 외부 게시본 + 운영 DB(관리자 화면) — 약관 네 곳(계획 4). **운영 DB 는 배포로 덮이지 않는다 — 관리자 화면 갱신이 마지막 단계다** |
| 번역 금지 문구 | `docs/i18n/translation-workflow.md` 검수 체크리스트 |

## 답변 기록

| 날짜 | 답변자 | 질문 번호 | 결론 | 근거 문서 |
| --- | --- | --- | --- | --- |
| | | | | |

## 게이트 반영

- [ ] `docs/i18n/legal/launch-gates.md` 의 07 행을 언어별로 채웠다
````

- [ ] **Step 2: 근거 경로를 확인한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: `인용한 경로가 모두 있다`

- [ ] **Step 3: 준거법 조항이 지금 정말 없는지 다시 확인한다**

Run: `grep -n "준거법\|관할\|분쟁\|governing\|jurisdiction" server/src/main/resources/consent/terms.txt || echo "조항 없음 확인"`
Expected: `조항 없음 확인`. 줄이 나오면 그 조항을 시트 `왜 필요한가` 표에 반영하고 질문 1 을 고친다.

- [ ] **Step 4: 검토자에게 전달한다 (법무 담당 확정 후)**

시트 `상태` → `질문 전달`, 이슈 댓글. 항목 01·04·08 의 약관 문구 변경과 **같은 검토자·같은 날** 보낸다(약관 네 곳을 한 번에 고치는 편이 어긋남이 적다).

- [ ] **Step 5: 답변을 기록한다**

`답변 기록` 을 채우고 `상태` → `답변 받음`. 번역 금지 문구 목록을 시트 `산출물` 아래에 붙인다.

- [ ] **Step 6: 반영하고 게이트를 채운다**

조항 추가·수정은 계획 4(약관 네 곳, **운영 DB 는 배포로 덮이지 않으므로 관리자 화면 갱신이 마지막 단계**)에 요청한다. 번역 금지 문구는 `docs/i18n/translation-workflow.md` 검수 체크리스트에 더한다(파일이 있을 때). `launch-gates.md` 의 07 행을 채우고 시트 `상태` → `닫힘`.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/07-terms-governing-law.md docs/i18n/legal/launch-gates.md
```

(Step 6 에서 번역 절차 문서를 고쳤으면 `docs/i18n/translation-workflow.md` 도 명시해 더한다.)

---

## Task 10: 항목 08 — 개인정보방침 게시본 언어별

**Files:**
- Create: `docs/i18n/legal/08-privacy-page-per-language.md`

**Interfaces:**
- Consumes: `tool/check_public_pages.py` · `PROJECT-ELUM-PUBLIC-PAGES-CHECK.yaml` · 스토어 공개 주소 기록
- Produces: 언어별 게시 URL 표와 스토어 콘솔 연결표, 우선 언어·시행일 불일치 규칙, 검사기 확장 요구(계획 4 가 구현). `launch-gates.md` 의 08 행.

- [ ] **Step 1: 질문지를 만든다**

`docs/i18n/legal/08-privacy-page-per-language.md`:

````markdown
# 항목 08. 개인정보방침 게시본 — 언어별

- 상태: 미착수
- 담당(법무): 미정 (게시·검사 자동화는 개발 담당)
- 검토 요청일: —
- 영향: 언어별 — 게시본이 없는 언어는 열지 않는다
- 출시 차단: 예

## 왜 필요한가 (근거)

방침은 **두 곳에 산다** — 서버가 들고 있는 동의 문서와 외부에 게시한 페이지(gh-pages). 한국어 게시본만 있고, 스토어 콘솔도 그 주소를 가리킨다.

| 사실 | 근거 |
| --- | --- |
| 게시 주소는 `https://twin-fang.github.io/elum/` 아래 `privacy.html` · `delete.html` · `index.html` 한국어 페이지뿐이다 | `tool/check_public_pages.py` (`BASE`, `PAGES`) |
| 서버 문서와 게시본의 일치를 매주 검사한다. **한국어 페이지 하나만 검사한다** | `.github/workflows/PROJECT-ELUM-PUBLIC-PAGES-CHECK.yaml` |
| 게시본은 이 저장소 밖(gh-pages)에서 바뀔 수 있다 | 같은 워크플로 머리말 |
| 스토어가 개인정보 URL 을 요구한다(App Store 는 로케일별, Play 는 앱당 하나) | `docs/projectops/store/20260921_스토어_문구_원본.md` 「공개 주소」 |
| 스펙: 개인정보방침과 삭제 페이지의 **언어별 게시본**이 필요하고, 검사 워크플로를 언어별로 확장한다 | `docs/superpowers/specs/2026-10-02-multi-language-design.md` 4.4 |

## 질문

1. 언어별 게시 URL 규칙을 어떻게 두는가(예: `/en/privacy.html`)? Play 는 개인정보 URL 이 **앱당 하나**인데, 언어별 페이지로 가는 언어 전환 링크가 있는 하나의 주소로 충분한가?
2. 언어별 게시본이 법무 확정본과 일치한다는 것을 **누가 · 언제** 확인하는가? 언어마다 시행일·버전이 어긋날 때 어느 언어가 우선하는가(항목 07 의 우선 언어와 같이 답한다)?
3. 삭제 안내 페이지(`delete.html`)도 언어별이 필요한가? 스토어의 데이터 삭제 URL 요건과 어떻게 맞추는가?
4. 방침 게시본에 법역별로 반드시 들어가야 하는 표기(사업자 정보 · 대리인 · 문의처)가 있는가?
5. 게시본이 없는 언어의 앱 화면에서 방침 링크를 어디로 보낼 것인가(`en` 으로 대체하지 않는다는 스펙 원칙과 충돌하지 않게)?

## 산출물

- [ ] 언어별 게시 URL 표와 스토어 콘솔 연결표
- [ ] 우선 언어·시행일 불일치 처리 규칙
- [ ] `tool/check_public_pages.py` 를 언어별로 확장하기 위한 요구(계획 4 가 구현): 검사 대상 페이지 목록, 언어별 필수 문구

## 답변이 나오면 고칠 곳

| 결론이 | 고칠 곳 |
| --- | --- |
| 게시 URL 규칙 | 게시본(gh-pages) + `tool/check_public_pages.py` 의 `PAGES` · `BASE` + 앱의 방침 링크 + `client/ios/fastlane/store/<로케일>/privacy_url.txt`(계획 6) |
| 검사 확장 | `.github/workflows/PROJECT-ELUM-PUBLIC-PAGES-CHECK.yaml` 의 `paths` 와 검사기 — 계획 4 |

## 답변 기록

| 날짜 | 답변자 | 질문 번호 | 결론 | 근거 문서 |
| --- | --- | --- | --- | --- |
| | | | | |

## 게이트 반영

- [ ] `docs/i18n/legal/launch-gates.md` 의 08 행을 언어별로 채웠다
````

- [ ] **Step 2: 근거 경로를 확인한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: `인용한 경로가 모두 있다`

- [ ] **Step 3: 검사기가 지금 한국어 하나만 보는지 확인한다**

Run: `grep -n "^PAGES\|^BASE" tool/check_public_pages.py`
Expected: `PAGES = ("index.html", "privacy.html", "delete.html")` 와 `BASE = "https://twin-fang.github.io/elum"` — 언어 구분이 없다. 달라졌다면 시트 `왜 필요한가` 표를 고친다.

- [ ] **Step 4: 검토자에게 전달한다 (법무 담당 확정 후)**

시트 `상태` → `질문 전달`, 이슈 댓글. 항목 07(우선 언어)과 함께 보낸다.

- [ ] **Step 5: 답변을 기록한다**

`답변 기록` 을 채우고 `상태` → `답변 받음`. 언어별 게시 URL 표를 시트에 붙인다.

- [ ] **Step 6: 반영하고 게이트를 채운다**

검사기 확장과 게시본 작성은 계획 4 와 개발 담당이 한다. 스토어 콘솔의 언어별 개인정보 URL 은 계획 6 의 `privacy_url.txt` 로 들어간다. `launch-gates.md` 의 08 행을 채우고 시트 `상태` → `닫힘`.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/08-privacy-page-per-language.md docs/i18n/legal/launch-gates.md
```

---

## Task 11: 항목 09 — 언어와 법역 축

**Files:**
- Create: `docs/i18n/legal/09-language-vs-jurisdiction.md`

**Interfaces:**
- Consumes: 스펙 4.4 · 8장, 항목 01~08 의 법역별 답
- Produces: **언어별 출시 국가·법역 표**, **지역 축 필요 여부 결론**, 필요하다면 키 구조 확장 요청서(계획 4), 스페인어 변종 결정. `launch-gates.md` 의 09 행과 각 언어의 `해당 법역`.

이 항목이 **마지막에 닫힌다** — 앞 항목들의 법역별 답이 모여야 "약관을 언어로만 나눠도 되는가"가 결론난다. 결론이 "지역 축이 필요하다"이면 이 계획은 코드를 바꾸지 않고 **스펙 4.4 를 갱신하는 새 하위 작업**을 만든다(마스터 C3 의 V34 를 확장하는 별도 설계 — 지금 미리 만들지 않는다).

- [ ] **Step 1: 질문지를 만든다**

`docs/i18n/legal/09-language-vs-jurisdiction.md`:

````markdown
# 항목 09. 언어와 법역 축

- 상태: 미착수
- 담당(법무): 미정
- 검토 요청일: —
- 영향: 모든 언어 — 약관 키 구조를 바꿀지가 여기서 정해진다
- 출시 차단: 예 — 다른 항목이 법역별 답을 내기 시작하면 이 항목이 구조 결론을 낸다

## 왜 필요한가 (근거)

스펙은 약관 단위를 **언어로만** 둔다. 언어와 법역은 같지 않다 — 스페인어는 스페인과 멕시코가, 영어는 미국과 영국이 법이 다르다. 법무가 지역 축이 필요하다고 하면 키 구조를 확장한다(지금 미리 만들지 않는다).

| 사실 | 근거 |
| --- | --- |
| 약관 키를 `(약관 키, 언어)` 한 쌍으로 바꾼다. 지역 축은 없다 | `docs/superpowers/specs/2026-10-02-multi-language-design.md` 4.4 |
| 스펙의 열린 질문: 스페인어 변종, 출시 국가 목록과 법역, 만 14세 기준의 국가별 분기 | 같은 문서 8장 |
| App Store 는 **175개국에 배포**돼 있다 — 언어가 한국어뿐이어도 이미 어디서든 설치된다 | `docs/projectops/store/20260921_스토어_문구_원본.md` |
| 스토어 로케일 코드는 `es-ES` / `es-MX`, `es-ES` / `es-419` 로 갈린다 — 변종이 정해져야 문구 폴더가 생긴다 | `docs/projectops/store/i18n/README.md`(계획 6) |
| 서버는 `Accept-Language` 로 언어를 정한다 — **국가를 알지 못한다** | 마스터 계획 C1 `docs/superpowers/plans/2026-10-02-i18n-0-master.md` |
| 이용자의 법역을 알 방법이 현재 코드에 없다(위치 · 국가 설정 수집 없음) | `server/src/main/resources/consent/privacy.txt` 2장(정확한 위치 미수집) |

## 질문

1. **출시 국가 목록**을 언어별로 확정해 달라(예: `en` = 미국 · 영국 · 호주 …, `es` = 스페인 · 멕시코 …, `ja` = 일본, `zh` = 간체 사용 지역 중 어디까지). 목록 밖 국가에서는 앱을 받지 못하게 해야 하는가, 받아도 되는가?
2. 같은 언어가 서로 다른 법역으로 나갈 때(예: `en` 이 미국과 EU 로 가면 GDPR 적용 여부가 갈린다) **약관·방침을 법역별로 따로 게시해야 하는가?** 즉 약관 키에 **지역 축이 필요한가**(예/아니오)? 필요하다면 최소한 어떤 구분(EEA 여부 / 국가)이면 되는가?
3. 서버가 국가를 모르는데, 법역별 약관이 필요하다면 이용자의 법역을 어떻게 정하는가(스토어 국가, 휴대폰 지역 설정, 이용자 선택)? 그 방법이 개인정보 수집(위치)에 해당하는가?
4. 스페인어 변종은 어느 것으로 시작하는가(스페인 / 중남미 / 중립)? 법적 문구(항목 01·02·04·07)도 변종별로 갈라야 하는가?
5. 중국 간체: 중국 본토를 출시 대상에 넣는가? 넣는다면 개인정보 국외 이전 요건(표준계약 · 보안평가)과 앱 등록이 출시 전 조건인가? 싱가포르 등 간체 사용 지역만 대상으로 하는가?
6. 일본: 일본 이용자의 개인정보를 한국 서버에 두고 미국 업체로 보내는 구조가 각각 외국 이전 규정에 걸리는가(항목 01 과 함께 답한다)?
7. 법무가 "지역 축이 필요하다"고 답하면, 키 구조를 `(약관 키, 언어, 지역)` 으로 확장하는 요청서를 계획 4 에 올린다. 아니라고 답하면 이 항목을 닫고 근거를 남긴다.

## 산출물

- [ ] 언어별 출시 국가 · 법역 표(`launch-gates.md` 의 `해당 법역` 칸을 채운다)
- [ ] **지역 축 필요 여부 결론(예/아니오)과 근거**
- [ ] 필요하다고 나오면: 키 구조 확장 요청서(계획 4 용)
- [ ] 스페인어 변종 결정(용어집·스토어 로케일에 반영)

## 답변이 나오면 고칠 곳

| 결론이 | 고칠 곳 |
| --- | --- |
| 지역 축 필요 | 새 하위 작업 — `consent_document` 키 구조(마스터 C3 V34)를 확장하는 별도 설계. 지금 코드는 바꾸지 않는다 |
| 지역 축 불필요 | 스펙 4.4 의 "언어로만 둔다" 가 확정된다 — 이슈 #521 에 근거를 남긴다 |
| 변종 결정 | `docs/i18n/glossary.md` 결정 항목 · `docs/projectops/store/i18n/README.md` 로케일 코드 |

## 답변 기록

| 날짜 | 답변자 | 질문 번호 | 결론 | 근거 문서 |
| --- | --- | --- | --- | --- |
| | | | | |

## 게이트 반영

- [ ] `docs/i18n/legal/launch-gates.md` 의 09 행과 각 언어의 `해당 법역` 을 채웠다
````

- [ ] **Step 2: 근거 경로를 확인한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: `인용한 경로가 모두 있다`(계획 6 의 `docs/projectops/store/i18n/README.md` 는 아직 없을 수 있어 건너뜀 안내가 나온다)

- [ ] **Step 3: 사용자가 출시 후보 국가 초안을 시트에 적는다**

법무가 답하기 전에 제품 쪽 초안이 있어야 질문 1 이 구체적이다. 언어별로 "열고 싶은 국가"를 시트 `질문` 위에 `제품 초안(사용자, <날짜>)` 으로 적는다. 정해진 것이 없으면 "정해진 것 없음"이라고 적는다.

- [ ] **Step 4: 검토자에게 전달한다 (법무 담당 확정 후)**

항목 01~08 의 답이 어느 정도 모인 뒤에 보낸다. 시트 `상태` → `질문 전달`, 이슈 댓글.

- [ ] **Step 5: 답변을 기록한다**

`답변 기록` 을 채우고 `상태` → `답변 받음`. 언어별 출시 국가·법역 표를 시트에 붙이고, **지역 축이 필요한가: 예/아니오** 를 시트 `산출물` 에 한 줄로 확정한다.

- [ ] **Step 6: 반영하고 게이트를 채운다**

각 언어의 `해당 법역` 을 `launch-gates.md` 의 언어별 서명 양식에 옮긴다. 지역 축이 "예"이면 이슈를 올리고 스펙 4.4 갱신을 요청한다(이 계획에서 구현하지 않는다). 스페인어 변종 결정은 `docs/i18n/glossary.md` 결정 항목과 `docs/projectops/store/i18n/README.md` 의 로케일 코드에 반영한다(파일이 있을 때). `launch-gates.md` 의 09 행을 채우고 시트 `상태` → `닫힘`.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add docs/i18n/legal/09-language-vs-jurisdiction.md docs/i18n/legal/launch-gates.md
```

---

## Task 12: 근거 경로 검사와 게이트 연결 확인

**Files:**
- Modify: `docs/i18n/legal/launch-gates.md` (언어를 열 때만 — 이 Task 에서는 구조 확인만)

**Interfaces:**
- Consumes: Task 1~11 의 시트와 게이트 표, 계획 5 의 `docs/i18n/language-launch-checklist.md` · `docs/i18n/launched-locales.txt`
- Produces: 시트 아홉 개와 게이트 표가 서로 맞고, 언어 오픈 체크리스트가 이 게이트를 가리키는 것을 확인한 상태

- [ ] **Step 1: 시트 아홉 개와 게이트 표의 항목이 일치하는지 본다**

Run:
```bash
ls docs/i18n/legal/0*.md | wc -l
grep -c "^| 0[1-9] |" docs/i18n/legal/launch-gates.md
for n in 01 02 03 04 05 06 07 08 09; do grep -q "launch-gates.md\` 의 $n 행" docs/i18n/legal/$n-*.md && echo "$n OK" || echo "$n 게이트 반영 줄 없음"; done
```
Expected: `9`, `9`, 그리고 `01 OK` … `09 OK`

- [ ] **Step 2: 인용한 근거 경로를 한꺼번에 검사한다**

Run: `bash docs/i18n/legal/check-evidence.sh`
Expected: 종료 코드 0, `인용한 경로가 모두 있다`. `건너뜀(다른 계획이 만든다)` 줄은 계획 5·6 이 아직 머지되지 않았을 때만 나온다 — 머지된 뒤에는 건너뜀이 없어야 한다. `옮겨짐(시트의 경로를 … 로 고친다)` 이 나오면(계획 4 가 `consent/` 를 `consent/ko/` 로 옮긴 경우) 시트의 경로를 알려 준 새 경로로 고치고 다시 돌린다. `❌ 없는 경로` 가 있으면 시트의 경로를 고친다.

- [ ] **Step 3: 언어 오픈 체크리스트가 이 게이트를 가리키는지 본다**

Run: `grep -n "legal/launch-gates.md" docs/i18n/language-launch-checklist.md`
Expected: 게이트 3·5 행에서 걸린다(계획 5 Task 11). 파일이 아직 없으면 계획 5 가 머지될 때 확인한다고 이슈에 적는다.

- [ ] **Step 4: 모든 시트의 상태를 한눈에 본다**

Run: `grep -H "^- 상태:" docs/i18n/legal/0*.md`
Expected: 지금은 모두 `미착수`. 이 표가 곧 법무 진행 현황이다. 이슈 #521 에 이 출력을 붙여 현황 댓글로 남긴다(`/pro-report`).

- [ ] **Step 5: 어느 언어도 아직 열 수 없음을 확인한다**

Run: `grep -c "미결" docs/i18n/legal/launch-gates.md`
Expected: 1 이상. 언어를 열려면 그 언어의 열에서 `미결` 이 0 이고, 서명 양식이 채워져 있어야 한다 — 이 두 조건이 계획 5 의 언어 오픈 체크리스트 3·5 행이다.

- [ ] **Step 6: 커밋 (`/pro-commit`)**

바뀐 파일이 있을 때만 한다(없으면 건너뛴다).

```bash
git add docs/i18n/legal/launch-gates.md
```

---

## 사용자 결정 · 확인이 필요한 것

| 항목 | 내용 |
| --- | --- |
| 법무 담당 | 누가 답하는가 — `README.md` 담당 칸이 `미정` 이다. 언어별로 법역을 아는 사람이 다를 수 있다 |
| TTS 서버 | 운영 주체와 소재지(항목 01 질문 5). 코드로는 알 수 없다 |
| 콘솔 값 | Play·App Store 신고와 배포 국가를 콘솔에서 확인·수정(항목 06). 이 계획은 레포 문서만 고친다 |
| 연령 기준 | 전 법역 통일(예: 16세)인지 법역별 분기인지(항목 02) — 법무 답 뒤 제품 결정 |
| 광고 지역 | EEA·영국에서 광고를 끌지, UMP 를 도입할지(항목 05) — 도입은 별도 기능 이슈 |
| 출시 후보 국가 | 언어별 초안(항목 09 Step 3) |
| 한국어 스토어 설명 | 콘솔에 이미 올라간 "먼저 가린 뒤에" 문장 갱신(계획 6 Task 7 의 D3) |

이 계획은 코드를 바꾸지 않는다. 배포도 하지 않는다.
