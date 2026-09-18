# 관리자 화면 개편

> 이슈: https://github.com/Twin-Fang/elum/issues/248

> 관련 설계: [이미지 프로바이더 추상화](./2026-09-18-image-provider-abstraction-design.md) ·
> [라이선스·권한](./2026-09-18-license-entitlement-design.md) ·
> [Free 픽토그램](./2026-09-18-free-pictogram-design.md)

## 배경

관리자 화면은 Thymeleaf + Tailwind + daisyUI 4로 만들어져 있다. 템플릿 12개,
총 1,019줄. 메뉴는 7개(대시보드 · 회원 · 루틴 · 프롬프트 · AI 모니터링 · 서버 로그 ·
시스템 설정)다.

**이미 잘 되어 있는 것부터 적는다** — 여기를 갈아엎으면 손해다.

- `settings.html`이 **`ConfigKey` 기반 자동 렌더링**이다. 그룹별 카드, SELECT는
  셀렉트박스, "변경됨" 배지, 기본값 복원 버튼까지 있다. **키를 추가하면 화면이
  저절로 생긴다.**
- 대시보드에 **오늘 AI 추정 비용**이 이미 나온다.
- 프롬프트 관리에 **미리보기·테스트**가 이미 있다.

즉 기능 뼈대는 있다. 문제는 다른 데 있다.

## 지금 무엇이 문제인가

### 1. Tailwind·daisyUI를 CDN에서 받는다

```html
<script src="https://cdn.tailwindcss.com"></script>
<link href="https://cdn.jsdelivr.net/npm/daisyui@4/dist/full.min.css" rel="stylesheet"/>
```

`cdn.tailwindcss.com`은 **브라우저에서 JIT 컴파일하는 개발용 빌드**다. 콘솔에
프로덕션 경고가 뜨고, 스타일이 적용되기 전 화면이 한 번 깜빡인다(FOUC). 외부 CDN이
느리거나 막히면 관리자 화면이 스타일 없이 뜬다.

### 2. 페이지마다 골격을 다시 쓴다

공유 프래그먼트가 `headAssets`와 `sidebar` **둘뿐**이다. 나머지는 페이지마다
직접 쓴다.

```html
<!DOCTYPE html>
<html ... data-theme="light">          ← 12개 파일에 반복
<head>...<th:block th:replace="...headAssets">
<body class="min-h-screen bg-base-100"> ← 반복
<div class="flex">                      ← 반복
  <div th:replace="...sidebar('xxx')">
  <main class="flex-1 p-8 space-y-6">   ← 반복
```

레이아웃을 한 번 바꾸려면 **12개 파일을 고쳐야 한다.** 다크모드·모바일을 넣지 못한
진짜 이유가 이것이다.

### 3. 휴대폰에서 못 쓴다

사이드바가 `w-64 min-h-screen` 고정이고 햄버거가 없다. 좁은 화면에서 본문이 밀린다.
서버 로그·AI 모니터링은 **자리에 없을 때 봐야 하는 화면**인데 폰에서 볼 수 없다.

### 4. 다크모드가 없다

`data-theme="light"`가 각 파일에 하드코딩돼 있다. daisyUI는 테마 전환을 기본
지원하는데 쓰지 않고 있다.

### 5. 공통 컴포넌트가 없다

테이블·페이지네이션·빈 상태·알림을 페이지마다 새로 짠다. 그래서 화면마다 생김새가
조금씩 다르고, 목록이 0건일 때 어떻게 보이는지가 화면마다 제각각이다.

### 6. 설정 화면이 곧 못 쓰게 된다 ⚠️

지금 `ConfigKey`는 8개다. 다른 두 설계가 들어오면:

| 출처 | 추가 키 |
| --- | --- |
| [① 이미지 프로바이더](./2026-09-18-image-provider-abstraction-design.md) | 6개 |
| [② 라이선스·권한](./2026-09-18-license-entitlement-design.md) | 12개 |
| **합계** | **26개** |

평면 목록 26줄에서 원하는 설정을 찾는 건 고통이다. **검색과 그룹 탭이 없으면
설정 화면이 기능을 잃는다.** 이것이 개편이 지금 필요한 가장 구체적인 이유다.

### 7. 저장할 때마다 전체 리로드

폼 submit → 리다이렉트 → `alert` div. 설정 하나 바꿀 때마다 페이지가 다시 그려지고,
스크롤 위치를 잃는다. 26개 설정을 만질 화면에서는 특히 나쁘다.

## 목표 / 비목표

**목표**

1. 레이아웃을 한 곳에서 바꾼다.
2. 휴대폰에서 쓸 수 있다.
3. 다크모드를 지원한다.
4. 설정이 26개로 늘어도 원하는 걸 바로 찾는다.
5. **이미지 프로바이더를 화면에서 바로 전환하고 비교한다.**
6. 구독을 화면에서 발급·회수한다.

**비목표**

- **프론트엔드 빌드 도구 도입(Node/Vite/PostCSS).** Spring Boot 빌드에 Node를 얹으면
  CI가 무거워지고 배포가 복잡해진다. 얻는 것(번들 크기)보다 잃는 것이 크다.
- SPA 전환. Thymeleaf를 유지한다.
- 관리자 권한 세분화(역할 분리). 지금 관리자는 소수다.

## 설계

### 1) 에셋을 정적 파일로 동봉한다

CDN 대신 `src/main/resources/static/admin/vendor/`에 Tailwind CSS 빌드본과
daisyUI CSS를 넣는다.

- 프로덕션 경고·FOUC 사라짐
- 외부 CDN 장애와 무관
- **빌드 도구를 추가하지 않는다** — 완성된 CSS 파일을 받아 커밋한다

> Tailwind 전체 CSS는 크다. 관리자 화면은 내부용이고 접속 빈도가 낮으므로
> 용량보다 **단순함과 무의존**을 택한다.

### 2) `page` 프래그먼트로 골격을 하나로

```html
<!-- admin-layout.html -->
<th:block th:fragment="page(title, active, content)">
  <!DOCTYPE html>
  <html data-theme="light">
  <head>
    <title th:text="'이룸 관리자 - ' + ${title}"></title>
    <link rel="stylesheet" th:href="@{/admin/vendor/tailwind.css}"/>
    <script th:src="@{/admin/js/theme.js}"></script>
  </head>
  <body>
    <div class="drawer lg:drawer-open">        <!-- daisyUI drawer = 모바일 대응 -->
      <input id="admin-drawer" type="checkbox" class="drawer-toggle"/>
      <div class="drawer-content">
        <div th:replace="~{:: topbar(${title})}"></div>
        <main th:replace="${content}"></main>
      </div>
      <div class="drawer-side">
        <div th:replace="~{:: sidebar(${active})}"></div>
      </div>
    </div>
  </body>
  </html>
</th:block>
```

각 페이지는 **본문만** 쓴다.

```html
<main th:fragment="content" class="p-4 lg:p-8 space-y-6">
  ... 이 화면만의 내용 ...
</main>
```

`drawer`는 daisyUI 기본 컴포넌트다. `lg:drawer-open`이면 넓은 화면에서 사이드바가
항상 열려 있고 좁은 화면에서는 햄버거로 접힌다. **모바일 대응이 클래스 하나로 끝난다.**

### 3) 다크모드

`theme.js`가 `localStorage`의 값을 읽어 `<html data-theme>`을 설정하고, 상단바
토글이 값을 바꾼다. 저장값이 없으면 `prefers-color-scheme`을 따른다.
**읽기·쓰기를 `try/catch`로 감싼다** — 사생활 보호 모드에서 `localStorage` 접근이
예외를 던질 수 있고, 그것 때문에 화면이 죽으면 안 된다.

### 4) 공통 프래그먼트

| 프래그먼트 | 용도 |
| --- | --- |
| `pageHeader(title, desc)` | 제목 + 설명 |
| `emptyState(message)` | **목록 0건** — 로딩과 구분되는 화면 |
| `toast()` | 저장 결과 알림 |
| `pagination(page)` | 목록 페이지 이동 |
| `statCard(title, value, desc)` | 대시보드 지표 |

`emptyState`를 공통으로 두는 이유는 CLAUDE.md 엣지케이스 규칙 때문이다 —
*"목록이 0건: 로딩과 구분되는 빈 상태 화면을 별도로 만든다."*

### 5) 설정 화면 개편

- **그룹 탭** — `ConfigGroup`별로 가른다 (Gemini 텍스트 / Gemini 이미지 /
  이미지 프로바이더 / 로컬 LLM / AI 요금 단가 / Free 플랜 / Pro 플랜)
- **검색** — 키 이름·라벨·설명으로 즉시 필터 (클라이언트 측, 서버 왕복 없음)
- **변경된 항목만 보기** — 기본값에서 벗어난 설정만 추린다
- **BOOLEAN 타입 추가** — `ConfigValueType`에 `BOOLEAN`을 더하고 토글 위젯을 그린다
  ([② 권한 설계](./2026-09-18-license-entitlement-design.md)가 요구한다)
- **저장은 fetch + 토스트** — 페이지 리로드 없이. 스크롤 위치를 잃지 않는다

### 6) 새 화면 — 이미지 프로바이더

설정 화면의 텍스트 입력만으로는 부족하다. 프로바이더마다 **상태**가 있기 때문이다.

```
┌─ Gemini 2.5 Flash Image ──────────── [사용 중] ─┐
│ $0.039/장 · 캐릭터 일관성 지원 · API 키 있음     │
└──────────────────────────────────────────────┘
┌─ GPT Image 1 Mini ─────────────────────────────┐
│ $0.005/장 · ⚠ 캐릭터 일관성 미지원 · API 키 있음 │
│                              [이것으로 전환]    │
└──────────────────────────────────────────────┘
┌─ FLUX schnell ─────────────────────────────────┐
│ $0.006/장 · ⚠ 캐릭터 일관성 미지원 · API 키 없음 │
│                              [전환 불가]        │
└──────────────────────────────────────────────┘
```

- `available()`이 false면 **전환 버튼을 막는다** (키 없는 프로바이더로 바꾸는 사고 방지)
- `supportsCharacterReference()`가 false면 **경고를 띄운다** —
  [①에서 설명한 대로](./2026-09-18-image-provider-abstraction-design.md) 캐릭터
  일관성이 깨지면 Pro의 가치가 사라진다
- **비교 테스트** — 같은 프롬프트로 프로바이더별 1장씩 생성해 나란히 본다.
  **1회 1장으로 제한한다** (비교 자체가 돈이다)

### 7) 새 화면 — 구독 관리

회원 상세(`member-detail.html`)에 섹션을 더한다.

- 현재 플랜 · 상태 · 만료일 · 발급 경로
- Pro 발급 (기간 + **사유 필수**)
- 회수

사유를 필수로 받는 이유는 나중에 "이 계정은 왜 Pro지"에 답하기 위해서다.

## 실패 경로

| 상황 | 동작 |
| --- | --- |
| `localStorage` 접근 예외 | try/catch로 삼키고 기본 테마로 렌더 |
| 설정 저장 실패 | 토스트로 **에러 코드와 함께** 표시. 입력값은 유지 |
| 키 없는 프로바이더로 전환 시도 | 버튼 비활성 + 서버에서도 거부 (이중 방어) |
| 목록 0건 | `emptyState` — 로딩과 구분되는 화면 |
| 비교 테스트 중 일부 프로바이더 실패 | 실패한 칸에 사유 표시, **나머지 결과는 보여준다** |
| 정적 에셋 로드 실패 | 스타일 없이라도 내용은 읽히게 시맨틱 마크업 유지 |

## 작업 순서

레이아웃을 먼저 하지 않으면 새 화면을 옛 골격 위에 또 만들게 된다.

```
1. page 프래그먼트 + drawer + 정적 에셋      ← 12개 템플릿 골격 교체
2. 공통 프래그먼트 (emptyState·toast·pagination)
3. 다크모드 토글
4. 설정 화면 (탭·검색·BOOLEAN·비동기 저장)
5. 이미지 프로바이더 화면                     ← ① 구현 후
6. 구독 관리 섹션                             ← ② 구현 후
```

1~4는 ①②와 **독립적으로 지금 할 수 있다.** 5~6은 각 백엔드가 있어야 한다.

## 열린 질문

1. **Tailwind 정적 파일을 어떤 방식으로 받을까.** 공식 standalone CLI로 한 번
   빌드해 커밋할지, 배포된 CSS를 그대로 받을지. 전자가 용량이 훨씬 작지만 갱신 절차가
   필요하다.
2. **비교 테스트 결과를 저장할까.** 나중에 다시 보려면 저장이 필요하지만, 이미지
   저장소가 커진다. 우선 저장하지 않고 화면에서만 본다.
