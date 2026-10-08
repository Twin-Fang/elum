import 'package:elum/core/storage/card_image_disk_cache.dart';

/// 디스크를 쓰지 않는 카드 그림 캐시. 실제 경로(path_provider)는 위젯 테스트 안에서 끝나지 않는다.
/// 폴더를 못 얻으면 캐시는 조용히 건너뛰므로 로그아웃·탈퇴가 바로 끝난다.
// ignore: strict_top_level_inference
noDiskCacheOverride() => cardImageDiskCacheProvider.overrideWithValue(
  CardImageDiskCache(
    rootProvider: () async => throw UnsupportedError('테스트에서는 디스크를 쓰지 않는다'),
  ),
);
