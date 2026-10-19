import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assets/app_assets.dart';
import '../logger/app_logger.dart';
import '../storage/local_storage.dart';

/// 칭찬 소리 두 가지: 카드 체크, 일과 전부 끝냄 (#777)
enum ChildPraiseKind { check, complete }

/// 칭찬 음성이 녹음된 일과 언어. 그 밖의 언어는 효과음만 (음성이 한국어 목소리)
const praiseVoiceLanguages = <String>{'ko'};

/// 체크 칭찬 음성 3개 (돌아가며 재생 — 매번 같은 말이면 금방 질린다)
const praiseCheckVoiceAssets = [
  AppAssets.soundPraiseCheck1,
  AppAssets.soundPraiseCheck2,
  AppAssets.soundPraiseCheck3,
];

/// 칭찬 소리 종류·일과 언어·순번 > 재생할 에셋 경로
///
/// 음성이 없는 언어는 효과음만. 일과 완료는 언어와 상관없이 팡파르 효과음이 앞에 붙어 있다.
String praiseAssetFor(
  ChildPraiseKind kind, {
  required String language,
  required int checkCount,
}) {
  final hasVoice = praiseVoiceLanguages.contains(language);
  if (!hasVoice) return AppAssets.soundChimeCheck;
  return switch (kind) {
    ChildPraiseKind.check =>
      praiseCheckVoiceAssets[checkCount % praiseCheckVoiceAssets.length],
    ChildPraiseKind.complete => AppAssets.soundPraiseDone,
  };
}

/// 실제로 소리를 내는 쪽. 테스트에서 가짜로 바꿔 끼운다.
abstract interface class PraiseSoundDriver {
  /// [assetPath] 는 `assets/` 로 시작하는 경로
  Future<void> play(String assetPath);
}

/// audioplayers 로 에셋을 재생. 카드 읽기 플레이어와 따로 둔다 (서로 끊지 않게)
class AudioPlayerPraiseDriver implements PraiseSoundDriver {
  AudioPlayerPraiseDriver({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// AssetSource 는 `assets/` 를 스스로 붙인다
  static const _assetPrefix = 'assets/';

  @override
  Future<void> play(String assetPath) async {
    final relative = assetPath.startsWith(_assetPrefix)
        ? assetPath.substring(_assetPrefix.length)
        : assetPath;
    await _player.stop();
    await _player.play(AssetSource(relative));
  }
}

/// 이룸이 칭찬 소리 창구: 스위치 확인 > 에셋 고르기 > 재생 (실패해도 화면 흐름은 계속)
class ChildPraiseSound {
  ChildPraiseSound({
    required PraiseSoundDriver driver,
    required bool Function() isOn,
  }) : _driver = driver,
       _isOn = isOn;

  final PraiseSoundDriver _driver;
  final bool Function() _isOn;

  /// 체크 칭찬 순번 (앱 실행 동안만)
  var _checkCount = 0;

  /// 기다리지 않아도 된다 — 소리 때문에 별 화면이 늦게 뜨면 안 된다
  Future<void> play(ChildPraiseKind kind, {required String language}) async {
    if (!_isOn()) return;
    final asset = praiseAssetFor(
      kind,
      language: language,
      checkCount: _checkCount,
    );
    if (kind == ChildPraiseKind.check) _checkCount++;
    try {
      await _driver.play(asset);
    } catch (e, st) {
      AppLogger.error('ChildPraiseSound.play(${kind.name})', e, st);
    }
  }
}

final praiseSoundDriverProvider = Provider<PraiseSoundDriver>(
  (ref) => AudioPlayerPraiseDriver(),
);

final childPraiseSoundProvider = Provider<ChildPraiseSound>(
  (ref) => ChildPraiseSound(
    driver: ref.watch(praiseSoundDriverProvider),
    // 설정에서 바꾼 값이 바로 반영되게 누를 때마다 읽는다
    isOn: () => ref.read(childPraiseSoundOnProvider),
  ),
);

/// 칭찬 소리 켜기/끄기. 보호자 설정·이룸이 설정이 같은 값 하나를 본다. 못 읽으면 켜짐
class ChildPraiseSoundOnNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      return ref.read(localStorageProvider).isChildPraiseSoundOn;
    } catch (e, st) {
      AppLogger.error('ChildPraiseSoundOnNotifier.build', e, st);
      return true;
    }
  }

  /// 값을 바꾸고 저장. 켤 때는 체크 칭찬을 한 번 들려준다
  Future<void> set(bool on) async {
    state = on;
    try {
      await ref.read(localStorageProvider).setChildPraiseSoundOn(on);
    } catch (e, st) {
      // 저장이 안 돼도 이번 실행 동안은 바뀐 값을 쓴다
      AppLogger.error('ChildPraiseSoundOnNotifier.set', e, st);
    }
    if (on) {
      await ref
          .read(childPraiseSoundProvider)
          .play(ChildPraiseKind.check, language: 'ko');
    }
  }
}

final childPraiseSoundOnProvider =
    NotifierProvider<ChildPraiseSoundOnNotifier, bool>(
      ChildPraiseSoundOnNotifier.new,
    );
