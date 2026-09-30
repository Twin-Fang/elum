
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

  test('줄여서 가져온다 — 긴 변 1600 · 품질 85 · 위치 권한을 따로 묻지 않는다', () async {
    ImageSource? source;
    double? w, h;
    int? q;
    bool? meta;
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async {
      source = s;
      w = maxWidth;
      h = maxHeight;
      q = imageQuality;
      meta = requestFullMetadata;
      return XFile.fromData(Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]));
    }).pick(PhotoSource.gallery);

    expect(r, isA<PhotoPicked>());
    expect((r as PhotoPicked).photo.bytes.length, 4);
    expect(source, ImageSource.gallery);
    expect(w, 1600);
    expect(h, 1600);
    expect(q, 85);
    expect(meta, isFalse);
  });

  test('카메라 권한 거부 — 카메라 쪽 거부다', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async =>
        throw PlatformException(code: 'camera_access_denied')).pick(PhotoSource.camera);

    expect(r, isA<PhotoPickDenied>());
    expect((r as PhotoPickDenied).source, PhotoSource.camera);
  });

  test('카메라가 없는 휴대폰도 같은 안내로 간다', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async =>
        throw PlatformException(code: 'no_available_camera')).pick(PhotoSource.camera);

    expect((r as PhotoPickDenied).source, PhotoSource.camera);
  });

  test('사진 접근 거부 — 갤러리 쪽 거부다', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async =>
        throw PlatformException(code: 'photo_access_denied')).pick(PhotoSource.gallery);

    expect((r as PhotoPickDenied).source, PhotoSource.gallery);
  });

  test('그 밖의 플랫폼 오류는 E-PHOTO-PICK 실패다', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async =>
        throw PlatformException(code: 'weird')).pick(PhotoSource.gallery);

    expect((r as PhotoPickFailed).failure.code, 'E-PHOTO-PICK');
  });

  test('갤러리 앱이 없어 예외가 나도 던지지 않고 실패로 준다', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async =>
        throw StateError('no activity found')).pick(PhotoSource.gallery);

    expect((r as PhotoPickFailed).failure.code, 'E-PHOTO-PICK');
  });

  test('빈 파일은 읽지 못한 것이다 — E-PHOTO-READ', () async {
    final r = await pickerWith((s, {maxWidth, maxHeight, imageQuality, requestFullMetadata = true}) async =>
        XFile.fromData(Uint8List(0))).pick(PhotoSource.gallery);

    expect((r as PhotoPickFailed).failure.code, 'E-PHOTO-READ');
  });
}
