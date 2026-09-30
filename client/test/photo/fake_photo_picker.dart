import 'dart:async';
import 'dart:typed_data';

import 'package:elum/features/guardian/data/card_photo.dart';
import 'package:elum/features/guardian/data/card_photo_picker.dart';

/// JPEG 시작 바이트만 갖춘 가짜 사진 — 서버 검사(형식) 를 통과한다.
PickedPhoto fakeJpeg() =>
    PickedPhoto(bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]));

/// 정해 둔 결과를 차례로 돌려주는 가짜 사진 고르기 — 카메라·갤러리를 실제로 열지 않는다.
class FakePhotoPicker implements CardPhotoPicker {
  FakePhotoPicker(this.results);

  final List<PhotoPickResult> results;

  /// 어떤 출처로 불렸는가.
  final List<PhotoSource> calls = [];

  /// 주면 그 Future 가 끝날 때까지 고르는 중으로 둔다(사진 앱이 떠 있는 상태).
  Completer<void>? hold;

  @override
  Future<PhotoPickResult> pick(PhotoSource source) async {
    calls.add(source);
    final gate = hold;
    if (gate != null) await gate.future;
    if (results.isEmpty) return const PhotoPickCancelled();
    return results.removeAt(0);
  }
}
