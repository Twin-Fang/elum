/// 기기 알림 권한 상태: 허용 / 거부 / 아직 안 물어봄
enum PushPermissionStatus {
  granted,
  denied,
  notDetermined;

  bool get isGranted => this == PushPermissionStatus.granted;
}
