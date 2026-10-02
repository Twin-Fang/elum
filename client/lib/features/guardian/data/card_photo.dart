import 'dart:typed_data';

import '../../../core/l10n/current_l10n.dart';
import '../../../core/network/app_failure.dart';
import '../../../shared/models/action_card.dart';

/// 사진을 어디서 가져오는가.
enum PhotoSource { camera, gallery }

/// 고른 사진 한 장 — 이미 줄여진 바이트다.
class PickedPhoto {
  const PickedPhoto({required this.bytes});

  final Uint8List bytes;
}

/// 서버 계약(#455)과 같은 기준을 앱도 먼저 본다.
///
/// 서버가 거절할 걸 알면서 5MB 를 올리면 보호자만 기다린다. 서버 검사는 그대로 두고
/// (마지막 방어선), 앱은 **보내기 전에** 같은 잣대로 걸러 이유를 바로 말한다.
abstract final class CardPhotoRules {
  static const maxBytes = 5 * 1024 * 1024;

  /// image_picker 로 줄이는 값. 폰 카메라 원본(수 MB)을 그대로 올리면 느리고 5MB 를 넘긴다.
  static const maxDimension = 1600.0;
  static const jpegQuality = 85;

  /// 확장자·MIME 은 믿지 않는다 — 앞 몇 바이트로 본다. 갤러리는 HEIC·WebP 도 준다.
  static PhotoMime? sniff(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return PhotoMime.jpeg;
    }
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return PhotoMime.png;
    }
    return null;
  }
}

enum PhotoMime {
  jpeg('image', 'jpeg', 'card.jpg'),
  png('image', 'png', 'card.png');

  const PhotoMime(this.type, this.subtype, this.fileName);

  final String type;
  final String subtype;
  final String fileName;
}

/// 실패 뒤 화면이 무엇을 내놓는가.
enum PhotoFailureKind {
  /// 같은 사진으로 다시 보낸다 — 네트워크·서버 일시 오류.
  retrySame,

  /// 다른 사진을 골라야 한다 — 형식·크기 문제라 같은 사진은 또 거절된다.
  pickAnother,

  /// 다시 해도 같다 — 내 일과가 아니거나 카드가 지워졌다. 알리고 닫는다.
  dismissOnly,
}

/// 사진 바꾸기 실패 한 건. 문구와 **식별자**를 함께 든다 (docs 예외처리 규칙).
class PhotoFailure {
  const PhotoFailure({
    required this.code,
    required String Function() messageOf,
    required this.kind,
  }) : _messageOf = messageOf;

  final String code;
  final PhotoFailureKind kind;
  final String Function() _messageOf;

  /// 사용자에게 보일 문구 — 앱 언어로 **읽을 때** 푼다(const 인스턴스가 언어에 묶이지 않게).
  String get message => _messageOf();

  static String _tooLarge() => appL10n.cardPhotoTooLarge;
  static String _wrongType() => appL10n.cardPhotoWrongType;
  static String _unreadable() => appL10n.cardPhotoUnreadable;
  static String _pickFailed() => appL10n.cardPhotoPickFailed;

  static const size = PhotoFailure(
    code: 'E-PHOTO-SIZE',
    messageOf: _tooLarge,
    kind: PhotoFailureKind.pickAnother,
  );

  static const type = PhotoFailure(
    code: 'E-PHOTO-TYPE',
    messageOf: _wrongType,
    kind: PhotoFailureKind.pickAnother,
  );

  static const unreadable = PhotoFailure(
    code: 'E-PHOTO-READ',
    messageOf: _unreadable,
    kind: PhotoFailureKind.pickAnother,
  );

  /// 사진 앱을 여는 것부터 실패했다 — 권한 거부·취소가 아닌 그 밖의 경우.
  static const pick = PhotoFailure(
    code: 'E-PHOTO-PICK',
    messageOf: _pickFailed,
    kind: PhotoFailureKind.pickAnother,
  );

  /// 서버·네트워크 실패를 사진 바꾸기의 말로 옮긴다.
  ///
  /// 문구는 서버 것이 이긴다(이미 해요체). 서버에 못 닿았으면 [AppFailure.hint] 가
  /// 무엇을 하면 되는지 말한다.
  factory PhotoFailure.from(AppFailure f) {
    final status = f.server?.statusCode;
    final kind = switch (status) {
      400 => PhotoFailureKind.pickAnother,
      401 || 403 || 404 => PhotoFailureKind.dismissOnly,
      _ => PhotoFailureKind.retrySame,
    };
    return PhotoFailure(
      code: f.badgeOr('E-PHOTO'),
      // 서버 문구는 그대로, 앱이 만든 문구(hint·기본)는 읽을 때 앱 언어로 푼다.
      messageOf: () => f.serverMessage ?? f.hint ?? appL10n.commonRetryLater,
      kind: kind,
    );
  }
}

/// 업로드 결과 — 카드 아니면 실패. 저장소는 던지지 않는다.
class PhotoUploadResult {
  const PhotoUploadResult.ok(ActionCard this.card) : failure = null;
  const PhotoUploadResult.failed(PhotoFailure this.failure) : card = null;

  final ActionCard? card;
  final PhotoFailure? failure;

  bool get isOk => card != null;
}

/// 사진으로 바꿀 수 있는 카드 — **서버에 저장된 카드만** 해당한다.
///
/// 사진은 `PUT /api/routines/{routineId}/steps/{stepId}/image` 로 서버 카드에 붙는다.
/// 서버 id 가 없는 카드(일과가 `local`·빈 값이거나 로컬에서 만든 `local_…` 카드)는
/// 올릴 곳이 없어, 칩을 보이면 눌러도 반드시 실패한다 — 그래서 **칩 자체를 두지 않는다.**
///
/// 지금 흐름에서 카드확인에 서 있는 카드는 대부분 서버 카드다(만드는 순간 서버에 임시저장,
/// `_createRoutine`). 서버 id 가 없는 경우는 서버 없이 로컬로 넣는 `addStep` 의
/// 예외 경로뿐이다.
class CardPhotoTarget {
  const CardPhotoTarget._(this.routineId, this.stepId);

  final String routineId;
  final String stepId;

  /// 서버 id 가 둘 다 있을 때만 만든다. 아니면 null(칩을 두지 않는다).
  static CardPhotoTarget? of({
    required String routineId,
    required String stepId,
  }) {
    final serverRoutine = routineId.isNotEmpty && routineId != 'local';
    final serverStep = stepId.isNotEmpty && !stepId.startsWith('local');
    if (!serverRoutine || !serverStep) return null;
    return CardPhotoTarget._(routineId, stepId);
  }
}
