# 온보딩_이름 화면 Figma 구현 설계

- 날짜: 2026-07-21
- 대상: `client` — `NameScreen`, `ElumTextField`, `AppAssets`
- Figma: `이룸` 파일 `온보딩_이름` 프레임 **두 장**
  - 204:991 — 빈 상태 (placeholder · CTA disable)
  - 204:1174 — 입력 완료 상태 (`하늘이` 입력됨 · CTA enable)

## 배경

시작 화면 → 온보딩_이름 화면 흐름은 이미 동작한다 (`SplashScreen`의 CTA가
`Routes.onboardingName`으로 이동). `NameScreen`도 이미 존재하지만 Figma 대비
두 가지가 빠져 있다.

| 갭 | 현재 | Figma (204:991) |
| --- | --- | --- |
| 입력 필드 좌측 아이콘 | 없음 | `Group 5` (204:999) 40×40, x=38 y=293 |
| placeholder 정렬 | 중앙 | 좌측 (텍스트 시작 x=90 — 아이콘 우측) |

제목·보조 문구·CTA·버튼 비활성 조건·뒤로가기 부재는 이미 Figma와 일치하므로
이번 작업 범위에 넣지 않는다.

### 두 프레임의 관계

204:1174는 **새 화면이 아니라 204:991의 입력 완료 상태**다. 두 프레임을 대조하면
아이콘·제목·보조 문구·필드·CTA의 좌표와 크기가 전부 동일하고, 다른 것은 두 가지뿐이다.

| 요소 | 204:991 (빈 상태) | 204:1174 (입력 완료) |
| --- | --- | --- |
| 필드 텍스트 | `이름을 입력해주세요` · `#DADADA` (204:998) | `하늘이` · `#000000` (204:1180) |
| CTA | `disable` · 배경 `#818393` · 텍스트 `rgba(255,255,255,0.5)` | `enable` · 배경 `#242634` · 텍스트 `#FFFFFF` |
| 필드 아이콘 | `Group 5` (204:999) | `Group 4` (204:1182) — 좌표·크기·색상 동일 |

둘 다 x=90 y=303, 20 / w400, 좌측 정렬이다. 즉 이 상태 전이는 **이미 코드가
처리하고 있다**.

- hint ↔ 입력값 전환 → `TextField` 기본 동작 (`hintStyle`과 `style`이 이미 분리돼 있다)
- CTA disable ↔ enable → `ElumButton`의 `onPressed`가 null인지로 variant가 갈리고,
  `NameScreen`이 `profile.canProceedFromName`을 넘긴다

따라서 204:1174 때문에 추가로 구현할 것은 없고, **회귀 테스트로 고정**한다
(아래 테스트 절 참고). 아이콘도 두 프레임이 같은 에셋이므로 한 번만 export한다.

**입력값 색상은 Figma의 `#000000` 대신 `textPrimary`(`#242634`)를 쓴다.**
204:1180의 fill은 디자인 토큰이 아니라 Figma 기본 검정(`Label Color/Light/Primary`)이
그대로 남은 값으로 보인다. 같은 화면의 제목(204:1179)이 `#242634`인데 입력값만
순검정이면 화면 안에서 두 종류의 검정이 섞이고, 앱 전체가 `#242634`를 텍스트
기본색으로 쓰고 있다. 픽셀 일치보다 토큰 일관성을 택한다.

## Figma 값 대조표 (204:991 기준)

204:1174에서 달라지는 값은 위 「두 프레임의 관계」 표에 있다.

| 요소 | Figma 노드 | 값 |
| --- | --- | --- |
| 프레임 | 204:991 | 393×852, 배경 `#F7F2EF` |
| 제목 | 204:996 | `아이를 어떻게\n불러드릴까요?` · Tmoney RoundWind 28 / w800 / `#242634` · x=24 y=131 |
| 보조 문구 | 204:997 | `정확한 실명이 아니어도 괜찮아요` · 16 / w400 / `#898B98` · x=24 y=211 |
| 입력 필드 | 204:992 | 344×68 · radius 20 · `#FFFFFF` + `#EFEFEF` 1px · x=24 y=279 |
| 필드 아이콘 | 204:999 | 40×40 · x=38 y=293 · 노란 원 `rgba(255,214,41,0.3)` + 어린이 머리 `#F3C500` |
| placeholder | 204:998 | `이름을 입력해주세요` · 20 / w400 / `#DADADA` · 좌측 정렬 · x=90 y=303 |
| CTA | 204:995 | `다음` · disable variant · 360×66 · x=16 y=675 |

아이콘 좌표에서 파생되는 여백:

- 필드 좌측(24) → 아이콘 좌측(38) = **좌측 여백 14**
- 아이콘 우측(38+40=78) → 텍스트 좌측(90) = **간격 12**

## 설계

### 1. 에셋

`Group 5`(204:999)는 Figma에서 `IMAGE-SVG` 노드이므로 원 배경과 아이콘을
분리하지 않고 **통째로 export**한다. 원을 Flutter `Container`로 다시 그리면
스플래시 화면에서 이미 겪은 "SVG 형태를 직접 그리다 어긋나는" 사고가 반복된다.

204:1174의 `Group 4`(204:1182)는 좌표·크기·색상이 204:999와 같은 아이콘이므로
**export는 한 번만** 한다.

- 저장 경로: `client/assets/images/icon_child_head.svg`
- `pubspec.yaml`은 `assets/images/` 디렉터리 단위로 등록되어 있어 수정 불필요

`AppAssets`에 상수를 추가한다.

```dart
// --- 입력 필드 아이콘 ---

/// 아이 이름 입력 필드의 좌측 아이콘 (40×40).
/// 노란 원 배경(rgba(255,214,41,0.3))과 어린이 머리(#F3C500)가 SVG 안에 함께 있다.
/// Figma `온보딩_이름`(204:991)의 Group 5.
static const inputFieldIconChildName = '$_images/icon_child_head.svg';
```

`inputFieldIcon` 접두어를 쓴다. 앞으로 일과 입력·목표 입력 등 다른 필드
아이콘이 늘어나면 `inputFieldIconRoutine`처럼 같은 계열로 붙어, 상수 이름만
보고도 "입력 필드 좌측에 들어가는 아이콘"임을 알 수 있다.

### 2. `ElumTextField` API 확장

```dart
const ElumTextField({
  super.key,
  required this.hintText,
  this.controller,
  this.onChanged,
  this.leadingIconAssetPath,
  this.explicitTextAlign,
});

/// 필드 왼쪽에 붙는 SVG 아이콘 경로. `AppAssets.inputFieldIcon*`을 넘긴다.
/// null이면 아이콘 영역 자체가 생기지 않는다.
final String? leadingIconAssetPath;

/// 정렬을 강제로 지정할 때만 넘긴다.
/// 평소에는 null로 두고 [resolvedTextAlign]의 판단에 맡긴다.
final TextAlign? explicitTextAlign;

/// 아이콘이 있으면 좌측, 없으면 중앙 정렬.
/// 아이콘은 왼쪽에 붙는데 텍스트만 가운데 뜨는 조합은 디자인상 존재하지 않으므로
/// 호출부가 매번 정렬을 넘기게 하지 않는다.
TextAlign get resolvedTextAlign =>
    explicitTextAlign ??
    (leadingIconAssetPath != null ? TextAlign.left : TextAlign.center);
```

**이름 선택 근거**

| 이름 | 근거 |
| --- | --- |
| `leadingIconAssetPath` | Material 예약어 `prefixIcon`(`Widget`을 받는다)과 충돌 회피. `AssetPath` 접미어로 위젯이 아니라 경로 문자열임을 타입 없이도 읽힌다 |
| `explicitTextAlign` | 종전 `textAlign = TextAlign.center` 기본값은 "호출부가 center를 의도"인지 "그냥 기본값"인지 구분할 수 없어 아이콘 유무를 반영할 수 없었다. `explicit`가 붙으면 넘기는 순간 자동 판단을 끈다는 의미가 드러난다 |
| `resolvedTextAlign` | getter가 계산 결과임을 드러낸다. 테스트가 이 getter를 직접 검증할 수 있어 렌더 트리를 파고들 필요가 없다 |

**정렬을 자동 판단하는 이유** — 아이콘은 왼쪽에 붙어 있는데 텍스트만 가운데
뜨는 조합은 어떤 디자인에서도 유효하지 않다. 유효하지 않은 상태는 애초에
표현할 수 없게 만든다. Flutter 표준 위젯도 같은 방식이다 (`ListTile`은
`leading` 유무로 `contentPadding`이, `AppBar`는 `leading` 유무로 `title`
위치가 바뀐다). 예외가 필요하면 `explicitTextAlign`으로 열어둔다.

**렌더링** — `InputDecoration.prefixIcon`에 넣되 Figma 좌표를 맞춘다.

```dart
prefixIcon: leadingIconAssetPath == null
    ? null
    : Padding(
        padding: EdgeInsets.only(left: 14.w, right: 12.w),
        child: SvgPicture.asset(leadingIconAssetPath!, width: 40.w, height: 40.w),
      ),
// 기본 최소폭 48이 적용되면 Figma 좌표가 밀린다
prefixIconConstraints: const BoxConstraints(),
```

기존 `textAlign` 파라미터는 `explicitTextAlign`으로 대체한다. 현재 호출부는
`NameScreen` 한 곳뿐이라 마이그레이션 부담이 없다.

### 3. `NameScreen` 변경

호출부 변경은 한 줄이다. 정렬은 자동으로 좌측이 된다.

```dart
ElumTextField(
  controller: _controller,
  hintText: '이름을 입력해주세요',
  leadingIconAssetPath: AppAssets.inputFieldIconChildName,
  onChanged: ref.read(onboardingProvider.notifier).setNickname,
),
```

## 테스트

`splash_screen_test.dart`의 `_svgWithAsset` 헬퍼를 `test/helpers/svg_finder.dart`로
옮겨 공유한다. 같은 헬퍼를 두 파일에 복사하면 한쪽만 고쳐지는 일이 생긴다.

### `test/name_screen_test.dart` (신설)

두 Figma 프레임을 각각 하나의 상태로 보고 group을 나눈다.

**`빈 상태 (204:991)`**

| 테스트 | 막는 사고 |
| --- | --- |
| Figma 문구 3종(제목 2줄 · 보조 문구 · placeholder)이 보인다 | 문구 임의 변경 |
| 필드 아이콘이 SVG 에셋으로 렌더링된다 | 원+아이콘을 `Container`로 직접 그리는 사고 (스플래시에서 실제 발생) |
| 입력 전에는 `다음`이 비활성이다 | 진행 조건 회귀 |

**`입력 완료 상태 (204:1174)`**

| 테스트 | 막는 사고 |
| --- | --- |
| 한 글자 입력하면 `다음`이 활성된다 | 진행 조건 회귀 |
| 입력하면 placeholder가 사라지고 입력값이 보인다 | hint와 입력값이 겹쳐 보이는 회귀 |
| 입력 후에도 필드 아이콘은 그대로 있다 | 204:1174에도 `Group 4`가 있다 — 상태 전이로 아이콘이 사라지면 안 된다 |
| 입력 후 `다음` → 목표 화면으로 이동 | 라우팅 회귀 |

CTA 활성 여부는 `ElumButton`의 `onPressed`가 null인지로 판정한다. 색상값을
직접 비교하면 토큰이 바뀔 때마다 테스트가 깨진다.

### `test/elum_text_field_test.dart` (신설)

| 테스트 | 내용 |
| --- | --- |
| `leadingIconAssetPath` 있으면 `resolvedTextAlign == TextAlign.left` | 자동 판단 규칙 고정 |
| 없으면 `TextAlign.center` | 기존 화면 회귀 방지 |
| `explicitTextAlign` 지정 시 그 값이 이긴다 | override 경로 보장 |

## 확장성

다음 필드 아이콘이 필요해지면 위젯 수정 없이 세 단계로 끝난다.

1. Figma에서 SVG export → `assets/images/`
2. `AppAssets`에 `inputFieldIconXxx` 상수 한 줄
3. 호출부에 `leadingIconAssetPath:` 한 줄

아이콘 크기가 40이 아닌 케이스가 나오면 그때 `leadingIconSize`를 추가한다.
지금은 넣지 않는다 (YAGNI).

## 범위 밖

- 뒤로가기 버튼 — Figma `온보딩_이름`에 없다
- 온보딩 진행 표시(`1 / 2`) — `docs/03-screens.md`의 러프 명세에는 있으나
  Figma 확정본에는 없다. Figma를 따른다.
- 제목·보조 문구·CTA·라우팅 — 이미 Figma와 일치한다
- 204:1174를 위한 별도 화면·위젯 — 같은 화면의 상태 전이이므로 만들지 않는다.
  회귀 테스트로만 고정한다.
- 상태바·홈 인디케이터 — iOS가 그린다. Figma에 있지만 구현 대상이 아니다.
