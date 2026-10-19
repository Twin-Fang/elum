import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/sound/child_praise_sound.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingDriver implements PraiseSoundDriver {
  final played = <String>[];

  @override
  Future<void> play(String assetPath) async => played.add(assetPath);
}

void main() {
  // 깨지면: 영어 일과에서 한국어 칭찬이 나오거나, 일과를 끝내도 큰 칭찬이 안 나온다
  test('일과 언어·종류 > 에셋: 한국어만 음성, 완료는 큰 칭찬', () {
    expect(
      praiseAssetFor(ChildPraiseKind.check, language: 'en', checkCount: 0),
      AppAssets.soundChimeCheck,
    );
    expect(
      praiseAssetFor(ChildPraiseKind.complete, language: 'ko', checkCount: 5),
      AppAssets.soundPraiseDone,
    );
    final rotated = [
      for (var i = 0; i < 3; i++)
        praiseAssetFor(ChildPraiseKind.check, language: 'ko', checkCount: i),
    ];
    expect(rotated.toSet().length, 3);
  });

  // 깨지면: 소리에 예민한 이룸이가 설정에서 꺼도 소리가 난다
  test('스위치가 꺼져 있으면 재생하지 않는다', () async {
    final driver = _RecordingDriver();
    var isOn = false;
    final sound = ChildPraiseSound(driver: driver, isOn: () => isOn);

    await sound.play(ChildPraiseKind.check, language: 'ko');
    expect(driver.played, isEmpty);

    isOn = true;
    await sound.play(ChildPraiseKind.check, language: 'ko');
    expect(driver.played, [AppAssets.soundPraiseCheck1]);
  });

  // 깨지면: 소리 재생 오류로 별 화면 흐름이 멈춘다
  test('재생이 실패해도 던지지 않는다', () async {
    final sound = ChildPraiseSound(driver: _FailingDriver(), isOn: () => true);
    await expectLater(
      sound.play(ChildPraiseKind.complete, language: 'ko'),
      completes,
    );
  });
}

class _FailingDriver implements PraiseSoundDriver {
  @override
  Future<void> play(String assetPath) async => throw StateError('no audio');
}
