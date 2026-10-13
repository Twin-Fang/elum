import 'package:elum/core/device/device_name_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버로 보내는 기기 이름은 보호자 화면에 그대로 나간다. 길이·제어 문자 정리는 서버가 맡는다.
void main() {
  test('제조사와 모델을 합치되, 모델이 제조사로 시작하면 겹쳐 쓰지 않는다', () {
    expect(androidDisplayName('samsung', 'SM-S921N'), 'Samsung SM-S921N');
    expect(androidDisplayName('Google', 'Google Pixel 9'), 'Google Pixel 9');
  });

  test('비었거나 공백뿐이면 이름 없음이다 — 연결은 막지 않는다', () {
    expect(normalizeDeviceName(null), isNull);
    expect(normalizeDeviceName('  \n\t '), isNull);
  });
}
