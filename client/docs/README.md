# client/docs — Flutter 앱 설계 문서

> 서비스 기획·백엔드·AI 설계는 저장소 루트 [`docs/`](../../docs/README.md)에 있다.
> 여기는 **Flutter 앱 구현에 필요한 문서**만 둔다.

| 문서 | 내용 | 언제 읽나 |
| --- | --- | --- |
| [design-system.md](./design-system.md) | Figma에서 추출한 색·타이포·간격·컴포넌트 토큰 | UI 코드 쓰기 전 항상 |
| [motion.md](./motion.md) | 애니메이션 duration·curve·눌림 반응 규칙 (토스 모션 철학) | 화면에 모션을 넣기 전 |
| [onboarding-flow.md](./onboarding-flow.md) | 온보딩 12개 프레임 화면별 명세 + 플로우 | 온보딩 구현 시 |
| [architecture.md](./architecture.md) | 폴더 구조, Riverpod 규칙, 라우팅, 서버 연동 | 새 기능 시작 시 |
| [troubleshooting.md](./troubleshooting.md) | 실제로 겪은 문제·원인·해결·재발 방지 | 에러를 만났을 때 |

코딩 규칙과 기술 스택은 [../CLAUDE.md](../CLAUDE.md)에 있다.

## 디자인 원본

Figma `이룸` 파일 — 최상위 트리 (node `238:1846`)
<https://www.figma.com/design/VSmGuv1iuOpLZmp6QeBHWr/%EC%9D%B4%EB%A3%B8?node-id=238-1846&m=dev>

## 문서 갱신 규칙

- **디자인이 바뀌면 코드보다 `design-system.md`를 먼저 고친다.** 토큰이 단일 진실 공급원이다.
- 각 문서 하단의 `미확정 사항`은 실제로 확정될 때마다 지운다. 남아있으면 아직 결정 안 된 것이다.
