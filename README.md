# 이룸 (ELUM)

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
## 최신 버전 : v2.12.3 (2026-10-02)

보호자가 적은 하루 일과를, 이룸이가 따라 할 수 있는 **그림 행동 카드**로 만들어 주는 앱이에요.
AI가 일과를 작은 행동으로 나누고 단계마다 그림을 그려 줘요. 카드는 보호자가 확인한 뒤에야 이룸이에게 보여요.

<!-- Google Play가 공개되면 두 번째 배지를 스토어 링크가 걸린 배지로 교체한다 -->
[![App Store에서 받기](https://img.shields.io/badge/App_Store-%EB%B0%9B%EA%B8%B0-black?logo=apple&logoColor=white)](https://apps.apple.com/kr/app/id6792970508)
![Google Play 출시 준비 중](https://img.shields.io/badge/Google_Play-%EC%B6%9C%EC%8B%9C_%EC%A4%80%EB%B9%84_%EC%A4%91-lightgrey?logo=googleplay&logoColor=white)

[도움말](https://twin-fang.github.io/elum/) · [개인정보처리방침](https://twin-fang.github.io/elum/privacy.html) · [계정·데이터 삭제 안내](https://twin-fang.github.io/elum/delete.html)

## 이렇게 써요

1. **보호자가 일과를 적어요.** "내일 비가 많이 올 예정이야. 학교에 갈 수 있게 준비해야 해."처럼 평소 말투 그대로요.
2. **AI가 카드로 만들고 보호자가 확인해요.** 어색한 곳은 보호자가 고칠 수 있어요.
3. **이룸이가 카드를 따라 해요.** 그림과 짧은 문장, 음성 안내, 체크리스트로 다음 행동을 알려 주고 마치면 별을 모아요.

보호자 화면과 이룸이 화면은 한 앱 안에 있고 비밀암호로 오가요.

## 이런 앱이에요

- **진단명을 묻지 않아요.** 개인화는 보호자가 고른 도움 목표만으로 해요.
- **한 카드에 하나의 행동만** 담아요.
- **이룸이가 고른 캐릭터**(고양이 루루, 여우 포포)가 모든 카드에 같이 나와요.
- **보상은 보호자가 정해요.** 앱은 별로 성취를 보여 주고, 간식·산책 같은 실제 보상은 보호자가 정한 대로 알려 줘요.
- **실패해도 멈추지 않아요.** 재시도 안내와 오류 번호를 보여 줘서 문제가 생긴 곳을 찾을 수 있어요.

---

## 개발자를 위한 정보

```
elum/
├── client/   Flutter 앱 (보호자 화면 + 이룸이 화면)
├── server/   Spring Boot 서버 (관리자 페이지 포함)
└── docs/     초기 기획·해커톤 기록 (현재 동작과 다를 수 있어요)
```

| 영역 | 사용 기술 |
| --- | --- |
| 앱 | Flutter, Dart, Riverpod, go_router |
| 서버 | Spring Boot, Java 21, PostgreSQL, Flyway |
| 로그인 | 카카오, 네이버, 구글, 애플 |
| AI | Gemini, OpenAI, fal (카드 문장과 그림) |
| 관리자 | Thymeleaf, daisyUI |
| 자동화 | GitHub Actions |

**앱 실행**

```bash
cd client
cp .env.example .env    # 필요한 키는 .env.example 주석에 있어요
flutter pub get
flutter run
```

서버는 `server/`에서 `./gradlew bootRun`으로 실행해요. PostgreSQL과 로컬 설정 파일이 필요하고, 작업 규칙은 [server/CLAUDE.md](./server/CLAUDE.md), [client/CLAUDE.md](./client/CLAUDE.md)에 있어요.

## 만든 사람들

해커톤 「2026 장애 플러스 기술」에 팀 룸룸(LUMLUM)으로 참가하며 시작했고, 지금은 스토어 출시를 향해 계속 만들고 있어요.

| 팀원 | 역할 |
| --- | --- |
| 서새찬 | PM · Frontend |
| 백지훈 | Backend · AI |
| 이예람 | UX/UI |

## 저작권

© 2026 팀 룸룸(LUMLUM). 모든 권리 보유. 자세한 내용은 [LICENSE](./LICENSE)를 참고해 주세요.
