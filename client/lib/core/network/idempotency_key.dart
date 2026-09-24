import 'dart:math';

/// 요청 멱등 키 — UUID v4 (#407).
///
/// 서버는 같은 키로 다시 온 생성 요청에 AI 를 다시 부르지 않고 저장된 결과를 준다.
/// 키가 겹치면 남의 요청으로 보이므로 암호학적 난수로 만든다. uuid 패키지를 들이지
/// 않는다 — 이 함수 하나가 쓸 곳의 전부다.
String newIdempotencyKey([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // 버전 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 변형
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
