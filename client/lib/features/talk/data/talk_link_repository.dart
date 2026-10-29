import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../../core/network/profile_header_interceptor.dart';
import '../domain/talk_json.dart';
import '../domain/talk_link.dart';

/// 일과를 링크로 보내기: 링크 만들기 · 내 켜진 링크. 끄기는 글 내리기([TalkRepository.delete])
/// 계정 단위 API라 이룸이 헤더를 싣지 않고, 실패는 [AppFailure] 로 던진다.
class TalkLinkRepository {
  TalkLinkRepository(this._dio);

  final Dio _dio;

  static final _accountLevelOptions = Options(
    extra: {ProfileHeaderInterceptor.skipKey: true},
  );

  /// 링크 만들기 (같은 일과의 켜진 링크가 있으면 그 링크)
  Future<TalkLinkCreated> create({
    required String routineId,
    List<String> blurredStepIds = const [],
  }) => _call('create', () async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/talk/links',
      data: {'routineId': routineId, 'blurredStepIds': blurredStepIds},
      options: _accountLevelOptions,
    );
    final created = TalkLinkCreated.fromJson(response.data ?? const {});
    if (created == null) throw const FormatException('malformed response');
    return created;
  });

  /// 내 켜진 링크: 원본 일과 id > 링크 글 id
  Future<Map<String, String>> fetchMyLinks() => _call('fetchMyLinks', () async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/talk/links/mine/by-source-routine',
      options: _accountLevelOptions,
    );
    final linkPostIdByRoutineId = <String, String>{};
    for (final entry in (response.data ?? const {}).entries) {
      final postId = TalkJson.nonEmptyText(entry.value);
      if (postId != null) linkPostIdByRoutineId[entry.key] = postId;
    }
    return linkPostIdByRoutineId;
  });

  /// 로그 + 모든 실패를 [AppFailure] 로 통일
  Future<T> _call<T>(String operation, Future<T> Function() body) async {
    try {
      return await logged('TalkLinkRepository', operation, body);
    } catch (e) {
      throw AppFailure.of(e);
    }
  }
}

final talkLinkRepositoryProvider = Provider<TalkLinkRepository>(
  (ref) => TalkLinkRepository(ref.watch(dioProvider)),
);
