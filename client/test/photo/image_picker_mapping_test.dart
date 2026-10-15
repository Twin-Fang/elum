
import 'package:elum/features/guardian/data/card_photo.dart';
import 'package:elum/features/guardian/data/card_photo_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// image_picker 가 던지는 것을 화면이 다루는 네 갈래로 옮긴다 (#456).
///
/// 취소 · 권한 거부 · 그 밖의 실패 · 성공. 플러그인은 실제로 열지 않고 함수를 끼운다.
void main() {
  ImagePickerCardPhotoPicker pickerWith(PickImageFn fn) =>
      ImagePickerCardPhotoPicker(pickImage: fn);

  test('사진 앱에서 그냥 돌아오면 취소다 — 오류가 아니다', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async => null)
        .pick(PhotoSource.camera);

    expect(r, isA<PhotoPickCancelled>());
  });

  test('카메라 권한 거부 — 카메라 쪽 거부다', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async =>
        throw PlatformException(code: 'camera_access_denied')).pick(PhotoSource.camera);

    expect(r, isA<PhotoPickDenied>());
    expect((r as PhotoPickDenied).source, PhotoSource.camera);
  });

  test('그 밖의 플랫폼 오류는 E-PHOTO-PICK 실패다', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async =>
        throw PlatformException(code: 'weird')).pick(PhotoSource.gallery);

    expect((r as PhotoPickFailed).failure.code, 'E-PHOTO-PICK');
  });

  test('빈 파일은 읽지 못한 것이다 — E-PHOTO-READ', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async =>
        XFile.fromData(Uint8List(0))).pick(PhotoSource.gallery);

    expect((r as PhotoPickFailed).failure.code, 'E-PHOTO-READ');
  });
}
