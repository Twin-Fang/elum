# 디자인 시스템 — 이룸(ELUM)

> 출처: Figma `이룸` 파일, 섹션 `온보딩` (node `238:3022`)
> [Figma 링크](https://www.figma.com/design/VSmGuv1iuOpLZmp6QeBHWr/%EC%9D%B4%EB%A3%B8?node-id=238-3022&m=dev)
>
> 아래 값은 **Figma에서 직접 추출**한 것이다. 눈대중으로 바꾸지 말고, 디자인이 바뀌면 이 문서를 먼저 고친다.

## 기준 캔버스

| 항목 | 값 |
| --- | --- |
| 프레임 크기 | **393 × 852** (iPhone 16 / 15 Pro) |
| 좌우 기본 여백 | **24px** |
| 배경색 | `#F7F2EF` (따뜻한 아이보리) |

> 다른 화면 크기 대응은 `MediaQuery` 기반 비율 계산이 아니라 **Flutter 기본 레이아웃 위젯**으로 흡수한다.
> 393 기준 좌표는 "이 간격이 의도된 값"이라는 근거이지, 절대 좌표로 박으라는 뜻이 아니다.

## 색상 (AppColors)

### 기본

| 토큰 | HEX | 용도 |
| --- | --- | --- |
| `background` | `#F7F2EF` | 온보딩 화면 배경 |
| `surface` | `#FFFFFF` | 카드·입력 필드 배경 |
| `textPrimary` | `#242634` | 제목·본문 |
| `textSecondary` | `#898B98` | 보조 설명 문구 |
| `textPlaceholder` | `#DADADA` | 입력 필드 placeholder |
| `border` | `#EFEFEF` | 입력 필드 테두리 (1px) |

### 브랜드 / 강조

| 토큰 | HEX | 용도 |
| --- | --- | --- |
| `brandPeach` | `#FFC9BB` | 브랜드 주색 (부드러운 살구) |
| `brandOrange` | `#FF8B22` | 강조·활성 상태 |
| `accentYellow` | `#FFD629` | 별 보상 |
| `accentGold` | `#F3C500` | 별 보상 (그림자) |
| `warmBrown` | `#443E39` | 시작 화면 텍스트 |

### 버튼 (컴포넌트셋 `187:299` — `일반 버튼`)

| 상태 | 배경 | 텍스트 |
| --- | --- | --- |
| **enable** | `#242634` | `#FFFFFF` |
| **disable** | `#818393` | `rgba(255,255,255,0.5)` |

> 온보딩 프레임의 인스턴스는 대부분 `disable`로 찍혀 있지만,
> 컴포넌트셋에는 `Property 1=enable` / `=disable` 두 variant가 정의되어 있다.
> **인스턴스가 아니라 컴포넌트셋(`187:299`)이 원본**이다.

### 선택 상태 — 용도마다 색이 다르다 ⚠️

미선택은 모두 `#FFFFFF` + `#EFEFEF` 1px로 같지만, **선택색은 셋 다 다르다.**

| 용도 | 배경 | 테두리 (2px) | 토큰 | 출처 |
| --- | --- | --- | --- | --- |
| 목표 칩 | `#B5EAEC` | `#93DBCC` | `goalSelected*` | `204:1147` |
| 캐릭터 — 여우 | `#FFDAC7` | `#EB9B73` | `foxSelected*` | `204:1121` |
| 캐릭터 — 고양이 | `#CED8FF` | `#9CADF1` | `catSelected*` | `204:1134` |

> 한때 이 셋을 `selectedFill`/`selectedBorder` **한 쌍으로 묶어놨었다.** 그래서 목표 칩에
> 여우색이 들어갔다. → [이슈 #11](https://github.com/Twin-Fang/elum/issues/11)
>
> 캐릭터 색은 `AppColors.characterSelected(CardCharacter)` switch로 얻는다.
> 새 캐릭터를 추가하면 컴파일 에러가 나므로 색 누락이 조용히 지나가지 않는다.

**Figma 명세가 없는 강조 표면**은 `highlightFill`/`highlightBorder`를 쓴다
(보호자 화면의 마스킹 결과·배지 등). 선택 상태 토큰을 끌어 쓰지 않는다.

### 캐릭터 / 일러스트 팔레트

`#FFFADB` `#FFDFBD` `#FFDAC7` `#F4A753` `#EB9B73` `#F3F2E1` `#CED8FF` `#C8DD94` `#B5EAEC` `#CDC8C3`

> 캐릭터 SVG 안에서만 쓰인다. UI 컴포넌트에 끌어 쓰지 않는다.

## 타이포그래피 (AppTypography)

폰트 패밀리: **`TmoneyRoundWind`** (둥근 고딕 — 아동 친화적)

| 토큰 | size | weight | lineHeight | 용도 |
| --- | --- | --- | --- | --- |
| `title` | 28 | w800 | 1.2 | 화면 제목 (2줄) |
| `buttonLarge` | 22 | w800 | 1.0 | 하단 CTA 버튼 |
| `headline` | 26 | w800 | 1.0 | 중앙 정렬 강조 |
| `subtitle` | 20 | w800 | 1.0 | 중앙 정렬 보조 제목 |
| `input` | 20 | w400 | 1.0 | 입력 필드 텍스트 |
| `body` | 16 | w400 | 1.0 | 설명 문구·목표 칩 |

> `lineHeight: 1em`이 많은 건 Figma에서 텍스트 박스를 수동으로 맞췄기 때문이다.
> Flutter에선 `height: 1.0`으로 두되, 한글 디센더가 잘리면 `1.15`까지 올려도 된다.

### 미확보 폰트

**`Cloudsofa_namgim`** (64px, w400) — 시작 화면 로고에만 쓰임. **폰트 파일 없음.**

→ 로고는 폰트 렌더링 대신 **SVG/PNG 에셋**으로 처리한다. `AppTypography`에 추가하지 않는다.

## 간격 (AppSpacing)

Figma 좌표에서 역산한 값.

| 토큰 | 값 | 근거 |
| --- | --- | --- |
| `screenH` | 24 | 좌우 기본 여백 (제목·설명·입력필드 x=24) |
| `xs` | 8 | |
| `sm` | 12 | 입력 필드 ↔ 아래 요소 |
| `md` | 16 | 버튼 좌우 여백 (x=16) |
| `lg` | 24 | 섹션 간격 |
| `xl` | 32 | 제목 블록 ↔ 콘텐츠 |

### 온보딩 공통 수직 리듬 (393×852 기준)

```
y=131   제목 (28/w800, 2줄, height 68)
y=211   설명 문구 (16/w400)      ← 제목 하단 +12
y=279   콘텐츠 시작 (입력 필드 등)  ← 설명 하단 +52
y=675   하단 CTA 버튼 (360×66)
```

## 컴포넌트

### 하단 CTA 버튼 (`일반 버튼`)

```
크기      360 × 66   (x=16, y=675)
radius    18px
텍스트    22 / w800 / 중앙정렬
disabled  bg #818393 · text rgba(255,255,255,0.5)
```

> 화면 폭 393에서 좌우 16씩 → **`EdgeInsets.symmetric(horizontal: 16)`** + `SizedBox(height: 66)`.
> 세이프에어리어 위에 띄우는 형태이므로 `bottom` 고정이 아니라 `SafeArea` 안에서 배치한다.

### 입력 필드

```
크기      344 × 68   (x=24, y=279)
radius    20px
배경      #FFFFFF
테두리    1px #EFEFEF
텍스트    20 / w400 / #242634
placeholder  #DADADA "이름을 입력해주세요" (중앙 정렬, x=90)
```

### 목표 선택 칩

`온보딩_목표`(`204:1002`)의 4개 항목.

```
칩        344×68 r20 · x=24 · y=279/365/451/537 (간격 18)
아이콘     40×40 · x=38 (칩 내부 좌측 14)
텍스트     16/w400 #000000 · x=90 (아이콘 우측 12)
```

1. 해야 할 일을 순서대로 이해해요
2. 필요한 준비물을 스스로 챙겨요
3. 새로운 상황을 미리 준비해요
4. 혼자 끝까지 해내는 경험을 만들어요

> 텍스트가 `#000000`이다. `textPrimary`(`#242634`)가 아니라 별도 토큰 `chipLabel`을 쓴다.

**아이콘은 4개가 전부 같다** — 노란 반투명 원 + `fi-br-child-head`.
`AppAssets.goalIcon` 상수 하나이며, 목표별 분기가 없다.
차별화가 필요하면 Figma를 먼저 바꾼다.

> 이 4개는 루트 docs의 `supportGoals`와 1:1 대응된다.
> **진단명을 묻지 않고 개인화하는** 서비스의 핵심 장치이므로 문구를 임의로 바꾸지 않는다.

## 구현 매핑

```
lib/core/theme/
├── app_colors.dart       # 위 색상 토큰
├── app_typography.dart    # 위 타이포 토큰 (TmoneyRoundWind)
├── app_spacing.dart       # 위 간격 토큰
└── app_theme.dart         # ThemeData 조립
```

## 미확정 사항

- 목표 칩 아이콘 SVG 에셋 (Figma `Group 5~8`) — 미추출
- 캐릭터 일러스트 SVG 에셋 (고양이 `187:853`, 여우 `217:1649`) — 미추출
- `Cloudsofa_namgim` 폰트 파일 확보 여부 (미확보 시 로고 이미지 에셋 유지)
- 다크모드 — Figma는 Light만 정의됨. 이번 범위에서 **제외**.
