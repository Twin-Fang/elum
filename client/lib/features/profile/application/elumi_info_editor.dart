import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../shared/models/character.dart';
import '../../member/application/member_providers.dart';
import '../../member/data/member_repository.dart';
import '../../onboarding/domain/image_style.dart';

/// 이룸이 정보 고치기: 이름·캐릭터·그림 방식을 지정한 이룸이에 저장 > 회원 정보 다시 받기 (#660)
///
/// 고른 이룸이가 아니어도 그 이룸이에 저장. 고른 이룸이면 다시 받은 회원 정보로 로컬 값까지 맞춰짐(프로필 세션)
class ElumiInfoEditor {
  ElumiInfoEditor(this._ref);

  final Ref _ref;

  MemberRepository get _repository => _ref.read(memberRepositoryProvider);

  Future<AppFailure?> rename(String profileId, String nickname) =>
      _saveThenRefresh(
        () => _repository.updateNickname(nickname, profileId: profileId),
      );

  Future<AppFailure?> changeCharacter(
    String profileId,
    CardCharacter character,
  ) => _saveThenRefresh(
    () => _repository.updateCharacter(character.apiValue, profileId: profileId),
  );

  Future<AppFailure?> changeImageStyle(String profileId, ImageStyle style) =>
      _saveThenRefresh(
        () =>
            _repository.updateImageStyle(style.apiValue, profileId: profileId),
      );

  /// 저장 > 성공이면 회원 정보 갱신. null 이면 서버까지 저장됨
  Future<AppFailure?> _saveThenRefresh(
    Future<AppFailure?> Function() save,
  ) async {
    final failure = await save();
    if (failure != null) return failure;
    await _refreshMember();
    return null;
  }

  /// 회원 정보 다시 받기 (실패 시 기존 값 유지 · 다음 주기 갱신에 맞춰짐)
  ///
  /// 저장 응답은 쓰지 않음: 응답의 당사자 칸(도움 목표 등)이 고친 이룸이 것이라 고른 이룸이 값에 섞임
  Future<void> _refreshMember() async {
    final fresh = await _ref.read(memberFetcherProvider)();
    if (fresh == null) {
      AppLogger.info(
        '[elumi info] saved but member refresh failed (kept previous member)',
      );
      return;
    }
    _ref.read(memberPrefetchProvider).put(fresh);
    _ref.invalidate(memberProvider);
  }
}

final elumiInfoEditorProvider = Provider<ElumiInfoEditor>(ElumiInfoEditor.new);
