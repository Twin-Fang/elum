import 'card_image_disk_cache.dart';
import 'local_storage.dart';
import 'token_store.dart';

/// 사용자가 스스로 나갈 때(로그아웃·탈퇴, 보호자·이룸이 공통) 이 휴대폰의 계정 흔적을 전부 지운다.
///
/// - 이룸이 표식·역할까지 지운다. 남으면 다음 시작이 연결 화면으로 끌려간다.
/// - 캐시(보호자가 올린 사진 포함)는 지운 뒤에 돌아온다. 끝났다고 알린 뒤에 남아 있으면 안 된다.
/// - 밖에서 끊긴 경우는 표식을 남겨야 하므로 `DeviceLinkRepository.releaseThisPhone` 을 쓴다.
Future<void> wipeLocalAccount({
  required TokenStore tokens,
  required LocalStorage storage,
  CardImageDiskCache? imageCache,
}) async {
  await tokens.clear();
  await storage.clearAll();
  await imageCache?.clear();
}
