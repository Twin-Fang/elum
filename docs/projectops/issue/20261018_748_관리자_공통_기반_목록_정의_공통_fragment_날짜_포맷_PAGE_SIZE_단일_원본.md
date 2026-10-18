📝 현재 문제점
---

- 관리자 목록 화면마다 페이저·필터·날짜 표기가 제각각이고, 서비스 4곳이 `PAGE_SIZE` 를 각자 선언한다.
- 정렬·페이지 파라미터가 잘못 들어오면 처리 방식이 화면마다 다르다.
- 이후 관리자 UX 재설계(설정·회원·일과·공지·의견·모니터링·대시보드)가 공통으로 쓸 기반이 없다.

🛠️ 해결 방안 / 제안 기능
---

- 선언형 목록 정의 `AdminListDefinition` / `AdminListQuery` / `AdminListDefaults` 도입 (잘못된 정렬·페이지는 기본값으로 보정).
- 공통 fragment `admin-list.html` (`pager`, `filterBar`, `table`, `lastChanged`), 날짜 포맷 `AdminDateFormatter`(`adminDate`).
- `PAGE_SIZE` 단일 원본 20 으로 치환하고 규칙 테스트로 봉인.
- 기존 URL·권한·저장 동작 변경 없음.

⚙️ 작업 내용
---

- 설계: docs/superpowers/specs/2026-10-18-admin-ux-redesign-design.md, 계획: docs/superpowers/plans/2026-10-18-admin-ux-redesign.md (Task 1)
- 테스트: AdminListQueryTest, AdminDateFormatterTest, AdminFragmentRenderTest, ArchitectureRulesTest

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
