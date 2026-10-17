📝 현재 문제점
---

- OpenAI 대시보드(platform.openai.com/logs)에 서버가 부른 글 생성 기록이 하나도 보이지 않는다. 카드를 만든 뒤 AI가 무엇을 받고 무엇을 돌려줬는지 대시보드에서 확인할 수 없다.
- 원인: 서버는 OpenAI를 Chat Completions(`/v1/chat/completions`)로 부르는데, 이 API는 요청에 `store: true`를 넣은 호출만 대시보드에 저장한다. 지금은 넣지 않아 저장되지 않는다.
- 문서 예제가 쓰는 Responses API 호출만 **Responses** 탭에 뜨므로, 우리 서버 호출은 그 탭에 원래 나오지 않는다. 우리 호출이 나올 자리는 **Completions** 탭이다.
- 관련 파일: `server/src/main/java/com/chuseok22/elumserver/ai/infrastructure/client/OpenAiTextClient.java`

🛠️ 해결 방안 / 제안 기능
---

- OpenAI 글 생성 요청에 `store: true`를 넣어 호출이 Logs → Completions 탭에 남게 한다.
- 호출 종류(일과 만들기 / 추가 질문)를 `metadata`로 붙여 대시보드에서 종류별로 걸러 볼 수 있게 한다.
- 비용: 저장 자체에는 추가 요금이 없다. 토큰 과금은 그대로다.
- 유의: 보호자가 쓴 원문이 OpenAI 쪽에 대시보드용으로 보관된다. 이 조직은 이미 무료 토큰을 위해 데이터 공유에 동의한 상태이고, 개인정보 처리방침 9항 "보유 기간은 전달받는 업체의 정책에 따름"에 포괄된다. 사용자 승인을 받았다.
- 그림 생성(`/v1/images/generations`)은 이번 범위가 아니다.

⚙️ 작업 내용
---

- OpenAI 글 생성 요청 본문에 저장 여부와 호출 종류 표시 추가
- 요청 본문에 두 값이 들어가는지 단위 테스트
- 배포 후 관리자 지시문 시험 1회로 Completions 탭에 뜨는지 확인

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
