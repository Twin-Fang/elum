📝 현재 문제점
---

- `client/lib/core`의 10개 파일이 `features`를 59줄 import한다. 공통 계층이 기능 계층에 기대는 거꾸로 된 구조다.
  - 네트워크 클라이언트가 auth와 profile을 안다.
  - 테마 색상과 에셋이 onboarding과 child의 도메인 타입을 안다.
  - 저장소 provider가 `features/onboarding/application/onboarding_notifier.dart` 안에 있다. 그래서 저장소를 쓰는 곳마다 onboarding을 import한다.
- 기능끼리도 얽혀 있다. 회원 정보 provider가 `routine_repository.dart` 안에 있어 guardian이 허브가 됐다. auth처럼 아래층이어야 할 모듈도 guardian과 onboarding을 import한다.
- 이런 규칙을 지키는지 검사하는 장치가 없다.

🛠️ 해결 방안 / 제안 기능
---

- 공용 도메인 타입(캐릭터, 지원 목표, 보상 캐릭터)을 `shared`로 옮긴다.
- 저장소 provider를 `core/storage`로 옮긴다.
- 회원 정보를 별도 모듈로 분리한다.
- 네트워크 클라이언트는 core 쪽 인터페이스만 알게 하고, 구현은 앱 시작 시점에 주입한다.
- import 규칙 검사 도구를 CI에 건다. 남은 위반은 허용 목록으로 동결한다.

⚙️ 작업 내용
---

- 저장소 키 문자열은 그대로 둔다. 이미 깔린 앱이 저장한 값을 계속 읽어야 한다.
- 지금 작업 중인 #560이 같은 파일을 고치고 있다. #560이 develop에 들어간 뒤에 착수한다.
- `flutter analyze`, 전체 `flutter test` 통과 확인
- 설계: `docs/superpowers/specs/2026-10-08-structure-cleanup-design.md` 8번

🙋‍♂️ 담당자
---

- 프론트엔드: Cassiiopeia
