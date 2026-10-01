📝 현재 문제점
---

- develop에 push할 때마다 `PROJECT-Flutter-CI`의 "코드 분석(flutter analyze)" 단계가 실패한다. 오늘(2026-10-01)만 연속으로 여러 번 실패했다.
- 원인은 `client/test/character_badge_test.dart`의 안 쓰는 import 경고 7건이다(`unused_import`).
  - `app_router.dart`, `child_home_screen.dart`, `routine_repository.dart`, `routine.dart`, `flutter_riverpod.dart`, `go_router.dart`, `helpers/test_storage.dart`
- iOS·Android 빌드 단계는 통과하는데 분석 단계만 경고로 실패해서, 진짜 문제가 생겼을 때 CI 실패 신호가 묻힌다.

🛠️ 해결 방안 / 제안 기능
---

- 테스트가 쓰지 않는 import 7줄을 지운다. 동작은 바뀌지 않는다.

⚙️ 작업 내용
---

- `client/test/character_badge_test.dart`에서 안 쓰는 import 제거
- 검증: `flutter analyze` 0건, 해당 테스트 통과

🙋‍♂️ 담당자
---

- 프론트엔드: Cassiiopeia
