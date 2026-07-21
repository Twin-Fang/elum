# 아동 보상/별 화면 — glow·별 위치·전환 애니메이션 정합 설계

> 작성 2026-07-22 · Figma 덤프 기준일 2026-07-22
> 대상 화면: 보상 화면(루미/포포/루루) · 별 누적 화면(아이_별)

## 배경

디자이너가 보상 계열 화면(밤하늘 배경 + 빛나는 별)을 다듬으면서, 현재 구현과
Figma 사이에 세 가지 차이가 확인됐다. 5개 Figma 노드가 이 화면들에 해당한다.

| 노드 | 이름 | 역할 |
| --- | --- | --- |
| `309:4055` | 아이_보상_루미 | 보상 화면 (병아리, 별 아래 캐릭터) |
| `334:4320` | 아이_보상_포포 | 보상 화면 (여우) |
| `343:4434` | 아이_보상_루루 | 보상 화면 (고양이) |
| `364:8219` | 아이_별 | 별 누적 결과 화면 ("N개의 별을 얻었어요") |
| `364:8283` / `334:4282` | Star 3 (blur) | 큰 별 뒤 **blur 후광 레이어 원본** |

## 요청 → 진단

| 요청 | 진단 |
| --- | --- |
| 1. 전환 애니메이션이 달라져야 함 | 보상/별 화면이 `builder:`로 등록돼 go_router 기본(iOS 수평 슬라이드) 전환을 탄다. 어두운 배경에 옆에서 밀려드는 게 부자연스럽다 |
| 2. 5개 노드 디자인 정합 | 아래 A·B·C에 포함 |
| 3. 랜덤이 하나만 나옴 | **코드상 이미 정상** (`RewardCharacter.pick()`이 lumi/popo/ruru 균등 랜덤). 재현 조건 불명확 → 이번 작업 대상 아님 |
| 4·5. glow 없음/확인 | Figma 큰 별 뒤엔 넓게 번지는 **blur(20px) 노란 후광**이 있는데, 현재 `GlowingSvg`는 `RadialGradient` 하나로 약한 글로우만 재현. 강한 후광이 빠졌다 |
| 6. 별과 캐릭터가 겹침 | 보상 화면에서 큰 별 하단과 캐릭터 머리가 거의 닿는다. **별만 위로** 올려 간격을 확보한다 (캐릭터는 그대로) |

## 작업

### A. 전환 애니메이션 — 슬라이드 → fade (요청 1)

`lib/core/router/app_router.dart` — `childReward`·`childStars` 두 라우트를
`builder:` → `pageBuilder: fadePage(state, ...)`로 바꾼다. 이미 있는 검증된 헬퍼
(`app_transitions.dart:38`, 온보딩 완료·보호자 홈이 사용)를 재사용한다.

- 전환 시간 `kPageTransitionDuration = AppMotion.slow` → 아동 모드 300ms 원칙 충족
- pop은 같은 전환을 역재생 → 뒤로가기 자동 fade-out

### B. 큰 별 blur 후광 (요청 4·5)

`lib/core/widgets/glowing_svg.dart` — `GlowingSvg`에 `haloBlur`(기본 0) 옵션 추가.
`haloBlur > 0`이면 별 SVG를 `ImageFiltered(ImageFilter.blur)` + 노란 tint로 한 겹
더 깔아 Figma의 "별 모양대로 번지는 빛"을 재현한다. 기존 `RadialGradient`는 은은한
바닥 글로우로 유지한다.

- 기본값 0이라 **기존 호출부(위성 별 등)는 안 깨진다**
- 큰 별 2곳에만 적용: `reward_star.dart`의 `_Star`, `child_stars_screen.dart`의 큰 별
- blur 세기·색은 구현 후 시뮬레이터 ↔ Figma PNG 대조로 실측 조정
  (Figma 20px blur와 Flutter sigma 스케일이 달라 값 그대로 쓰지 않는다)

**대안 검토**: blur 후광 전용 위젯 신규 생성 → 두 화면에서 중복 배치가 필요하고,
`GlowingSvg`가 이미 "glow 재현" 책임을 가진 위젯이라 옵션 추가가 응집도가 높다. 기각.

### C. 별-캐릭터 겹침 해소 (요청 6)

`lib/features/child/presentation/reward_screen.dart` `_RewardHero` — 보상 화면에서
별(`RewardStar`)만 위로 올려 별 하단과 캐릭터 머리 간격을 확보한다. 캐릭터 좌표
(`_charFrame`)는 그대로 둔다. 올린 만큼 별 상단이 상태바/노치에 잘리지 않는지,
`SizedBox` 높이 계산이 맞는지 확인한다.

- 별 누적 화면(아이_별)은 캐릭터가 없어 이 작업 대상 아님

### D. 랜덤 — 손대지 않음 (요청 3)

`RewardCharacter.pick()`은 코드상 정상. 사용자도 "일단 넘어가"로 확인. 재보상 정책
(같은 카드 재체크 시 보상 안 뜸)도 **현재 사양 유지**로 확정.

## 실패 경로 · 엣지케이스

- **B**: `ImageFiltered`+SVG blur가 저사양 기기에서 무거울 수 있으나 `haloBlur` 기본 0이라
  적용 화면(큰 별 2곳)에만 비용 발생. 정적 효과라 Reduce Motion과 무관 → 접근성 영향 없음
- **A**: 실패 경로 없음 (검증된 헬퍼 재사용, pop 자동 역재생)
- **C**: 별을 올릴 때 상단 클리핑·높이 계산 확인. 좁은 기기에서 캐릭터가 별에서 떨어지지 않게
  기존 `.w` 통일 규칙 유지

## 검증

1. `flutter analyze`
2. `flutter test` — 기존 보상/별 화면 위젯·골든 테스트 통과
3. 시뮬레이터 렌더 ↔ Figma PNG 대조 (glow 세기, 별 간격, 전환 느낌)
4. glow 추가로 골든이 바뀌면 **사람 눈 승인 후** `flutter test --update-goldens`
