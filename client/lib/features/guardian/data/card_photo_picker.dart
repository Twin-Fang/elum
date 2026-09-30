import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'card_photo.dart';

/// 사진 고르기 결과. **취소·거부·실패를 갈라 받는다** — 셋은 화면이 하는 일이 다르다.
sealed class PhotoPickResult {
  const PhotoPickResult();
}

/// 사진을 골랐다.
class PhotoPicked extends PhotoPickResult {
  const PhotoPicked(this.photo);
  final PickedPhoto photo;
}

/// 사진 앱에서 그냥 돌아왔다. **오류가 아니다** — 아무 일도 없어야 한다.
class PhotoPickCancelled extends PhotoPickResult {
  const PhotoPickCancelled();
}

/// 카메라·사진 접근이 막혔다(권한 거부·카메라 없음). 우회 경로를 내놓는다.
class PhotoPickDenied extends PhotoPickResult {
  const PhotoPickDenied(this.source);
  final PhotoSource source;
}

/// 사진 앱을 여는 것부터 안 됐다(사진 앱이 없거나 예상 못 한 오류).
class PhotoPickFailed extends PhotoPickResult {
  const PhotoPickFailed(this.failure);
  final PhotoFailure failure;
}

/// 카메라·갤러리에서 사진 한 장을 가져온다. **절대 throw 하지 않는다.**
abstract interface class CardPhotoPicker {
  Future<PhotoPickResult> pick(PhotoSource source);
}

/// `ImagePicker.pickImage` 모양 — 테스트가 플러그인 없이 갈아 끼운다.
typedef PickImageFn = Future<XFile?> Function(
  ImageSource source, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
  bool requestFullMetadata,
});

/// image_picker 로 가져온다.
///
/// **가져오면서 줄인다**(긴 변 1600 · 품질 85). 폰 카메라 원본은 수 MB 라 그대로 올리면
/// 느리고 서버 상한(5MB)을 넘기기 쉽다.
class ImagePickerCardPhotoPicker implements CardPhotoPicker {
  ImagePickerCardPhotoPicker({PickImageFn? pickImage})
    : _pickImage = pickImage ?? _systemPick;

  final PickImageFn _pickImage;

  /// 실제 플러그인 호출. 후면 카메라를 먼저 연다 — 물건을 찍는 용도다.
  static Future<XFile?> _systemPick(
    ImageSource source, {
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
  }) => ImagePicker().pickImage(
    source: source,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    imageQuality: imageQuality,
    preferredCameraDevice: CameraDevice.rear,
    requestFullMetadata: requestFullMetadata,
  );

  @override
  Future<PhotoPickResult> pick(PhotoSource source) async {
    try {
      final file = await _pickImage(
        source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: CardPhotoRules.maxDimension,
        maxHeight: CardPhotoRules.maxDimension,
        imageQuality: CardPhotoRules.jpegQuality,
        // 위치 정보까지 읽으려고 iOS 사진 보관함 권한을 따로 묻지 않는다 —
        // 사진에서 위치를 쓸 일이 없고, 안 물으면 갤러리는 권한 없이 열린다.
        requestFullMetadata: false,
      );
      // 사진 앱에서 그냥 돌아왔다
      if (file == null) return const PhotoPickCancelled();

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return const PhotoPickFailed(PhotoFailure.unreadable);
      return PhotoPicked(PickedPhoto(bytes: bytes));
    } on PlatformException catch (e) {
      // 카메라·사진 접근을 막았거나 카메라가 없다 — 우회 경로가 있는 상황이다
      if (e.code == 'camera_access_denied' || e.code == 'no_available_camera') {
        return const PhotoPickDenied(PhotoSource.camera);
      }
      if (e.code == 'photo_access_denied') {
        return const PhotoPickDenied(PhotoSource.gallery);
      }
      debugPrint('[photo] 사진 고르기 실패: ${e.code}');
      return const PhotoPickFailed(PhotoFailure.pick);
    } catch (e) {
      // 사진 앱이 없거나 예상 못 한 예외 — 화면이 죽지 않고 실패로 안내한다
      debugPrint('[photo] 사진 고르기 실패: $e');
      return const PhotoPickFailed(PhotoFailure.pick);
    }
  }
}

final cardPhotoPickerProvider = Provider<CardPhotoPicker>(
  (ref) => ImagePickerCardPhotoPicker(),
);

/// 휴대폰 설정 열기 — 권한을 거부한 사람이 켜러 가는 길.
///
/// **iOS 만 앱 설정 화면을 직접 열 수 있다.** 안드로이드는 카메라를 시스템 카메라 앱에
/// 맡기고 CAMERA 권한을 선언하지 않아 거부가 생기지 않는다(카메라가 없는 휴대폰만 온다).
/// 그래서 안드로이드는 버튼을 감추고 갤러리 길만 둔다.
abstract interface class PhotoSettings {
  bool get available;
  Future<bool> open();
}

class _SystemPhotoSettings implements PhotoSettings {
  @override
  bool get available => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<bool> open() async {
    try {
      return await launchUrl(Uri.parse('app-settings:'));
    } catch (e) {
      debugPrint('[photo] 설정 열기 실패: $e');
      return false;
    }
  }
}

final photoSettingsProvider = Provider<PhotoSettings>(
  (ref) => _SystemPhotoSettings(),
);
