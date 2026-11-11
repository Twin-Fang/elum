# 행동카드 내보내기 배치 고르기 · 카드 비율 고정 · Free 한 종류 (#1224)

## 왜

- 내보내기(#1073) 카드가 칸을 꽉 채우도록 늘어나(`Expanded` 그림 5 : 글 2) 장수·용지마다 카드 모양이 달라졌다. 그림은 `BoxFit.cover` 로 잘렸다.
- 오려 쓰는 카드는 A4 세로·4/6/8장만. 사용자 요청: 전부 고를 수 있어야 하고, 어떤 조합이든 카드·그림이 깨지거나 늘어나면 안 된다.
- Free 는 한 종류만, Pro 유도는 강하게. 화면은 EarLocAlert 설정 화면처럼 (묶음 목록 + 줄 오른쪽 값 + 아래 시트). HTML 목업 승인.

## 결정

**카드 모양 고정**
- 인쇄 카드 가로:세로 = 앱 카드 333:410 (`printCardAspectRatio`). `PrintCard` 가 스스로 `Center > AspectRatio` 로 감싸 어떤 칸에서도 모양을 지킨다.
- 그림 칸 4:3 고정 (`printCardPictureAspectRatio`), 큰 글자 테마는 그림 칸 폭 75%. 글은 남는 높이.
- 격자는 `bestCardGridLayout`: 장수 n 에 대해 열 1..n 을 재고 카드 폭이 가장 큰 것. 남는 곳은 여백.
- 카드 크기: 꽉 차게 1.0 · 보통 0.85 · 작게 0.7 (가장 큰 카드 대비).

**고르는 값**: 형태(카드 한 장씩 · 일과 한 장 · 오려 쓰는 카드) · 용지 방향(세로/가로, A4 595×842 / 842×595) · 한 장에 1·2·4·6·8장(오려 쓰는 카드) · 카드 크기 · 디자인 · 카드 문장.
PDF·인쇄도 용지 방향을 따른다 (`PdfPageFormat.a4.landscape`).

**Free / Pro**
- 새 권한 `CARD_EXPORT_ALL_LAYOUTS` (`FREE_` false · `PRO_` true, 관리자 요금제·구독 화면). 응답 `cardExportAllLayouts`.
- Free: 카드 한 장씩 + 기본 디자인. 잠긴 형태·배치·디자인은 Pro 배지와 함께 보이고(살 수 있을 때), 고르면 그 값의 첫 지면을 Pro 미리 보기(`CardExportProTeaser`)로 보이고 그 자리로 스크롤.
- Free 화면 아래 Pro 안내 판 + 민트 버튼 (요금제 화면, 형태·배치 혜택을 맨 위로).
- 화면이 들고 있는 설정은 그릴 때마다 `limitedTo(권한)` 를 거친다 (Pro 가 끝난 뒤 남은 설정이 파일로 나가지 않게).
- 기본 형태는 카드 한 장씩 (Free 가 고를 수 있는 값).
- 이룸 로고(Free 아래 띠) 16 > 24pt.

## 실패 경로

그림 못 받은 카드: 지금처럼 제목만 크게. 저장·PDF·인쇄 실패: 지금 오류 코드 그대로. 옛 서버(권한 필드 없음): 앱은 false 로 읽어 Free 처럼 잠금 — 서버를 먼저 배포한다.

## 하지 않는 것

새 테마·그림 꾸밈, 서버 PDF, 다른 언어 번역(번역 단계), 앱 심사 배포.

## 확인

- 서버: `SystemConfigEntitlementServiceTest` (Pro 키 > `cardExportAllLayouts`, 기본값 Free false · Pro true)
- 앱: 앱 시험은 두지 않음(#848). `flutter analyze` · `tool/check_*` · 실제 위젯 렌더(지면 10종, 옵션 화면 Free/Pro)로 확인
