<!-- This is an auto-generated comment: release notes by coderabbit.ai -->

## Summary by CodeRabbit

## 릴리스 노트

* **버그 수정**
  * 켜진 앱이 가만히 있으면 새 프레임이 없어 다음 프레임에 띄우려던 토스트 콜백이 다음 터치까지 밀렸다. 콜백을 예약할 때 프레임도 함께 요청한다. iOS 시뮬레이터(이룸이 폰)에서 켜진 앱에 초대 링크를 3번 열어 모두 토스트가 뜨는 것을 확인했다

<!-- end of auto-generated comment: release notes by coderabbit.ai -->
