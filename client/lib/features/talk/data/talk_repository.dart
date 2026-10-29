import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../../core/network/profile_header_interceptor.dart';
import '../domain/talk_block_entry.dart';
import '../domain/talk_comment.dart';
import '../domain/talk_json.dart';
import '../domain/talk_post.dart';
import '../domain/talk_preview.dart';

/// 이야기: 피드·글·댓글·도움이 됐어요·가져오기·신고·차단·이용 규칙 동의.
/// 전부 계정 단위 API라 이룸이 헤더를 싣지 않고, 실패는 [AppFailure] 로 던진다.
class TalkRepository {
  TalkRepository(this._dio);

  final Dio _dio;

  // 계정 단위 API: X-Profile-Id 생략 (가져오기는 body 의 profileId 를 쓴다)
  static final _accountLevelOptions = Options(
    extra: {ProfileHeaderInterceptor.skipKey: true},
  );

  /// 피드 한 쪽 (최신순). category 는 서버 값(SELF_CARE 등), 없으면 전체
  /// cursor 는 특수문자가 있어 queryParameters 로만 넘김
  Future<TalkFeedPage> fetchFeed({String? category, String? cursor}) =>
      _call('fetchFeed', () async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/talk/posts',
          queryParameters: {'category': ?category, 'cursor': ?cursor},
          options: _accountLevelOptions,
        );
        return TalkFeedPage.fromJson(_mapBodyOf(response));
      });

  /// 내가 쓴 글 한 쪽 (최신순, 내린 글 제외). cursor 는 queryParameters 로만 넘김
  Future<TalkFeedPage> fetchMyPosts({String? cursor}) =>
      _call('fetchMyPosts', () async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/talk/posts/mine',
          queryParameters: {'cursor': ?cursor},
          options: _accountLevelOptions,
        );
        return TalkFeedPage.fromJson(_mapBodyOf(response));
      });

  Future<List<TalkPostSummary>> fetchPopular({String? category}) =>
      _call('fetchPopular', () async {
        final response = await _dio.get<List<dynamic>>(
          '/api/talk/posts/popular',
          queryParameters: {'category': ?category},
          options: _accountLevelOptions,
        );
        return TalkJson.list(response.data, TalkPostSummary.fromJson);
      });

  /// 내가 이야기에 올린 글: 원본 일과 id > 글 id (일과관리 목록의 올림 표시용)
  Future<Map<String, String>> fetchMySharedPosts() =>
      _call('fetchMySharedPosts', () async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/talk/posts/mine/by-source-routine',
          options: _accountLevelOptions,
        );
        final sharedPostIdByRoutineId = <String, String>{};
        for (final entry in _mapBodyOf(response).entries) {
          final postId = entry.value;
          if (postId is String && postId.isNotEmpty) {
            sharedPostIdByRoutineId[entry.key] = postId;
          }
        }
        return sharedPostIdByRoutineId;
      });

  Future<TalkPostDetail> fetchDetail(String postId) =>
      _call('fetchDetail', () async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/talk/posts/${Uri.encodeComponent(postId)}',
          options: _accountLevelOptions,
        );
        return _requireParsed(TalkPostDetail.fromJson(_mapBodyOf(response)));
      });

  /// 올리기 미리보기: 이름을 가린 제목·카드와 보호자 사진 여부
  Future<TalkPreview> preview(String routineId) => _call('preview', () async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/talk/posts/preview',
      data: {'routineId': routineId},
      options: _accountLevelOptions,
    );
    return _requireParsed(TalkPreview.fromJson(_mapBodyOf(response)));
  });

  /// 글 올리기 > 만들어진 글 id
  Future<String> create({
    required String routineId,
    required String category,
    String? note,
    List<String> blurredStepIds = const [],
  }) => _call('create', () async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/talk/posts',
      data: {
        'routineId': routineId,
        'note': note,
        'category': category,
        'blurredStepIds': blurredStepIds,
      },
      options: _accountLevelOptions,
    );
    return _requireParsed(
      TalkJson.nonEmptyText(_mapBodyOf(response)['postId']),
    );
  });

  /// 한마디·분류 고치기: 보낸 항목만 바뀌고, note 가 빈 문자열이면 한마디를 지운다
  Future<TalkPostDetail> update(
    String postId, {
    String? note,
    String? category,
  }) => _call('update', () async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/talk/posts/${Uri.encodeComponent(postId)}',
      data: {'note': ?note, 'category': ?category},
      options: _accountLevelOptions,
    );
    return _requireParsed(TalkPostDetail.fromJson(_mapBodyOf(response)));
  });

  Future<void> delete(String postId) => _call('delete', () async {
    await _dio.delete<void>(
      '/api/talk/posts/${Uri.encodeComponent(postId)}',
      options: _accountLevelOptions,
    );
  });

  Future<void> markHelpful(String postId) => _call('markHelpful', () async {
    await _dio.put<void>(
      '/api/talk/posts/${Uri.encodeComponent(postId)}/helpful',
      options: _accountLevelOptions,
    );
  });

  Future<void> unmarkHelpful(String postId) => _call('unmarkHelpful', () async {
    await _dio.delete<void>(
      '/api/talk/posts/${Uri.encodeComponent(postId)}/helpful',
      options: _accountLevelOptions,
    );
  });

  /// 댓글 한 쪽 (오래된 순)
  Future<TalkCommentPage> fetchComments(String postId, {String? cursor}) =>
      _call('fetchComments', () async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/talk/posts/${Uri.encodeComponent(postId)}/comments',
          queryParameters: {'cursor': ?cursor},
          options: _accountLevelOptions,
        );
        return TalkCommentPage.fromJson(_mapBodyOf(response));
      });

  Future<TalkComment> addComment(String postId, String body) =>
      _call('addComment', () async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/talk/posts/${Uri.encodeComponent(postId)}/comments',
          data: {'body': body},
          options: _accountLevelOptions,
        );
        return _requireParsed(TalkComment.fromJson(_mapBodyOf(response)));
      });

  Future<void> deleteComment(String commentId) =>
      _call('deleteComment', () async {
        await _dio.delete<void>(
          '/api/talk/comments/${Uri.encodeComponent(commentId)}',
          options: _accountLevelOptions,
        );
      });

  /// 일과관리로 가져오기: groupId 가 없으면 묶음 밖 맨 앞, 있으면 그 묶음의 맨 뒤
  Future<TalkImportResult> importToLibrary(
    String postId, {
    required String profileId,
    String? groupId,
  }) => _call('importToLibrary', () async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/talk/posts/${Uri.encodeComponent(postId)}/import',
      data: {'profileId': profileId, 'groupId': groupId},
      options: _accountLevelOptions,
    );
    return _requireParsed(TalkImportResult.fromJson(_mapBodyOf(response)));
  });

  /// 신고: targetType POST·COMMENT, reason PERSONAL_INFO·OFFENSIVE·ADVERTISING·OTHER
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
  }) => _call('report', () async {
    await _dio.post<void>(
      '/api/talk/reports',
      data: {'targetType': targetType, 'targetId': targetId, 'reason': reason},
      options: _accountLevelOptions,
    );
  });

  /// 차단: 글·댓글 중 하나만 넘기면 그 글쓴이를 차단한다
  Future<void> block({String? postId, String? commentId}) =>
      _call('block', () async {
        await _dio.put<void>(
          '/api/talk/blocks',
          data: {'postId': postId, 'commentId': commentId},
          options: _accountLevelOptions,
        );
      });

  Future<void> unblock(String blockId) => _call('unblock', () async {
    await _dio.delete<void>(
      '/api/talk/blocks/${Uri.encodeComponent(blockId)}',
      options: _accountLevelOptions,
    );
  });

  Future<List<TalkBlockEntry>> fetchBlocks() => _call('fetchBlocks', () async {
    final response = await _dio.get<List<dynamic>>(
      '/api/talk/blocks',
      options: _accountLevelOptions,
    );
    return TalkJson.list(response.data, TalkBlockEntry.fromJson);
  });

  /// 이야기 이용 규칙에 동의했는가
  Future<bool> hasAgreedRules() => _call('hasAgreedRules', () async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/member/talk-rules-agreement',
      options: _accountLevelOptions,
    );
    return TalkJson.flag(_mapBodyOf(response)['hasAgreed']);
  });

  Future<void> agreeRules() => _call('agreeRules', () async {
    await _dio.post<void>(
      '/api/member/talk-rules-agreement',
      options: _accountLevelOptions,
    );
  });

  /// 로그 + 모든 실패를 [AppFailure] 로 통일
  Future<T> _call<T>(String operation, Future<T> Function() body) async {
    try {
      return await logged('TalkRepository', operation, body);
    } catch (e) {
      throw AppFailure.of(e);
    }
  }

  Map<String, dynamic> _mapBodyOf(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) throw const FormatException('empty response');
    return body;
  }

  /// 파싱 실패(null)는 형식 오류로 던진다 (빈 화면 대신 에러 화면)
  T _requireParsed<T>(T? parsed) {
    if (parsed == null) throw const FormatException('malformed response');
    return parsed;
  }
}

final talkRepositoryProvider = Provider<TalkRepository>(
  (ref) => TalkRepository(ref.watch(dioProvider)),
);
