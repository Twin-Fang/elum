<!-- This is an auto-generated comment: release notes by coderabbit.ai -->

## Summary by CodeRabbit

## 릴리스 노트

* **버그 수정**
  * 로그인하지 않은 휴대폰이 연결 암호만으로 이룸이 화면에 들어가던 길을 막았습니다. 로그인 화면의 "이룸이 휴대폰이에요 · 연결 암호 넣기" 링크를 없앴습니다.
  * 이룸이 휴대폰도 로그인 → 역할 선택(이룸이) → 연결 암호 넣기 순서로 연결합니다. 보호자가 연결을 끊은 휴대폰과 다시 켠 휴대폰도 로그인 화면에서 시작하며, 연결 화면에서 "연결이 끊어졌어요"를 알려 줍니다.
  * 연결 암호 링크를 열면 코드를 기억해 두었다가 로그인 뒤 연결 화면에 채웁니다.
  * 서버도 로그인한 휴대폰에서만 연결 암호를 받습니다.

<!-- end of auto-generated comment: release notes by coderabbit.ai -->

