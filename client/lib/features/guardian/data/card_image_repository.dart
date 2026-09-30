import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/action_card.dart';
import 'card_image_disk_cache.dart';
import 'card_photo.dart';

/// 카드 이미지를 받아오고, 보호자가 고른 사진으로 바꾼다.
///
/// 서버가 AI로 만든 그림을 인증된 요청에만 준다.
/// `GET /api/routines/{routineId}/steps/{stepId}/image` → `image/png`
///
/// **`Image.network`를 쓸 수 없어 여기가 필요하다.** 그 위젯은 Authorization
/// 헤더를 붙이지 못해 401을 받는다. 바이트를 직접 받아 화면에 넘긴다.
///
/// **절대 throw하지 않는다.** 이미지 한 장 때문에 카드가 사라지면 안 된다.
class CardImageRepository {
  CardImageRepository({Dio? dio, CardImageDiskCache? diskCache})
      : _dio = dio ?? DioClient.create(),
        _disk = diskCache;

  final Dio _dio;

  /// 기기 저장소 캐시. 없으면(null) 예전처럼 매번 네트워크로만 받는다.
  final CardImageDiskCache? _disk;

  /// 진행 중인 요청. 같은 그림을 여러 위젯이 동시에 달라고 해도 받기·쓰기는 한 번이다.
  final Map<String, Future<Uint8List?>> _inFlight = {};

  /// 디스크 → 네트워크 순으로 그림을 준다. 실패하면 null. 화면은 캐릭터 일러스트로 대체한다.
  ///
  /// [imagePath] 가 없으면 서버에 그림이 아직 없다는 뜻이라 디스크도 네트워크도 보지 않는다
  /// (그림이 생겨 값이 오면 열쇠가 달라져 [cardImageProvider] 가 다시 부른다).
  Future<Uint8List?> fetch({
    required String routineId,
    required String stepId,
    required String? imagePath,
  }) {
    if (imagePath == null || imagePath.isEmpty) return Future.value(null);
    return _inFlight[imagePath] ??= _load(routineId, stepId, imagePath)
        .whenComplete(() {
      // 값을 돌려주면 whenComplete 가 그 Future 를 기다려 자기 자신을 물고 멈춘다 — 블록으로 쓴다
      _inFlight.remove(imagePath);
    });
  }

  Future<Uint8List?> _load(String routineId, String stepId, String imagePath) async {
    final disk = _disk;
    // 다운로드 도중 로그아웃(캐시 삭제)이 있었는지 알아보려고 시작 시점을 적어 둔다
    final generation = disk?.generation;

    final cached = await disk?.read(imagePath);
    if (cached != null) return cached;

    final bytes = await _download(routineId: routineId, stepId: stepId);
    if (bytes == null) return null;

    // 저장 실패는 캐시가 삼킨다 — 받은 그림은 그대로 화면에 간다
    await disk?.write(imagePath, bytes, generation: generation);
    return bytes;
  }

  Future<Uint8List?> _download({
    required String routineId,
    required String stepId,
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        '/api/routines/$routineId/steps/$stepId/image',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('[card] 이미지 조회 실패 → 대체 일러스트 사용: $e');
      return null;
    }
  }

  /// 카드 그림을 사진으로 바꾼다 (#456 · 서버 #455).
  ///
  /// `PUT /api/routines/{routineId}/steps/{stepId}/image` · multipart · 필드 `image`.
  /// 200 은 카드 한 장이고 **`imagePath` 는 매번 바뀌는 새 열쇠**다 — 화면은 이 값이
  /// 바뀐 것을 보고 이미지 캐시를 버린다([cardImageProvider]).
  ///
  /// **절대 throw 하지 않는다.** 형식·크기는 서버가 거절하기 전에 앱이 먼저 걸러 이유를
  /// 말한다. 사진 바이트는 로그에 남기지 않는다(원칙 5).
  Future<PhotoUploadResult> uploadPhoto({
    required String routineId,
    required String stepId,
    required PickedPhoto photo,
  }) async {
    final bytes = photo.bytes;
    if (bytes.isEmpty) return const PhotoUploadResult.failed(PhotoFailure.unreadable);
    if (bytes.length > CardPhotoRules.maxBytes) {
      return const PhotoUploadResult.failed(PhotoFailure.size);
    }
    final mime = CardPhotoRules.sniff(bytes);
    if (mime == null) return const PhotoUploadResult.failed(PhotoFailure.type);

    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/routines/$routineId/steps/$stepId/image',
        data: FormData.fromMap({
          'image': MultipartFile.fromBytes(
            bytes,
            filename: mime.fileName,
            contentType: DioMediaType(mime.type, mime.subtype),
          ),
        }),
        // 보내는 쪽 제한 — 기본은 없어서, 망이 끊긴 채 올리면 스피너가 끝없이 돈다.
        // 받는 쪽과 같은 값을 쓴다(사진은 수 MB 라 다른 요청보다 오래 걸린다).
        options: Options(sendTimeout: AppConfig.receiveTimeout),
      );
      final body = res.data;
      if (body == null) {
        return PhotoUploadResult.failed(
          PhotoFailure.from(const AppFailure(fault: NetworkFault.app)),
        );
      }
      final card = ActionCard.fromJson(body);
      // 새 열쇠가 없으면 그림이 바뀌었다고 말할 수 없다 — 성공으로 착각하지 않는다
      if (card.imagePath == null || card.imagePath!.isEmpty) {
        return PhotoUploadResult.failed(
          PhotoFailure.from(const AppFailure(fault: NetworkFault.app)),
        );
      }
      return PhotoUploadResult.ok(card);
    } catch (e) {
      debugPrint('[card] 사진 업로드 실패: $e');
      return PhotoUploadResult.failed(PhotoFailure.from(AppFailure.of(e)));
    }
  }
}

final cardImageRepositoryProvider = Provider<CardImageRepository>(
  (ref) => CardImageRepository(
    dio: ref.watch(dioProvider),
    diskCache: ref.watch(cardImageDiskCacheProvider),
  ),
);

/// 카드 한 장의 이미지.
///
/// 같은 카드를 여러 화면(카드확인·아이 홈)에서 보여주므로 캐시가 필요하다.
/// **성공한 그림만** 메모리에 붙들고, 디스크에도 저장돼 앱을 다시 켜도 남는다 (#462).
/// 1MB가 넘는 이미지를 화면마다 다시 받으면 느리고 비싸다.
///
/// **실패(null)는 붙들지 않는다.** 붙들면 오프라인에서 한 번 실패한 카드가 앱을 다시 켤
/// 때까지 기본 그림에 갇힌다. 위젯이 사라졌다 다시 그려질 때 한 번 더 시도한다
/// (자동 재시도 루프는 없다).
///
/// **캐시 열쇠에 `imagePath` 를 넣는다 (#456).** 보호자가 사진으로 바꾸면 서버가 새
/// `imagePath` 를 준다. 열쇠가 (일과, 카드)뿐이면 옛 그림이 캐시에 그대로 남아 바꾼 사진이
/// 안 보이고, 이룸이 화면도 같은 옛 그림을 든다. 값이 바뀌면 열쇠가 달라 새로 받는다.
final cardImageProvider = FutureProvider.autoDispose.family<
    Uint8List?,
    ({String routineId, String stepId, String? imagePath})>(
  (ref, key) async {
    // 결과가 나오는 동안 버려지지 않게 먼저 붙든다. 실패하면 아래에서 놓는다.
    final link = ref.keepAlive();

    final bytes = await ref.watch(cardImageRepositoryProvider).fetch(
          routineId: key.routineId,
          stepId: key.stepId,
          imagePath: key.imagePath,
        );
    if (bytes == null) link.close();
    return bytes;
  },
);
