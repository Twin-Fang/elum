import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../../core/network/profile_header_interceptor.dart';
import '../../talk/domain/talk_json.dart';
import '../domain/expert_routine.dart';

/// 전문가 일과: 목록·미리 보기·가져오기. 계정 단위 API 라 이룸이 헤더를 싣지 않고, 실패는 [AppFailure] 로 던진다
class ExpertRoutineRepository {
  ExpertRoutineRepository(this._dio);

  final Dio _dio;

  // 계정 단위 API: X-Profile-Id 생략 (가져오기는 body 의 profileId 를 쓴다)
  static final _accountLevelOptions = Options(
    extra: {ProfileHeaderInterceptor.skipKey: true},
  );

  /// 목록. category 는 서버 값(SELF_CARE 등), 없으면 전체. 언어는 요청 언어(Accept-Language)
  Future<List<ExpertRoutineSummary>> fetchList({String? category}) =>
      _call('fetchList', () async {
        final response = await _dio.get<List<dynamic>>(
          '/api/expert-routines',
          queryParameters: {'category': ?category},
          options: _accountLevelOptions,
        );
        return TalkJson.list(response.data, ExpertRoutineSummary.fromJson);
      });

  Future<ExpertRoutineDetail> fetchDetail(String expertRoutineId) =>
      _call('fetchDetail', () async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/expert-routines/${Uri.encodeComponent(expertRoutineId)}',
          options: _accountLevelOptions,
        );
        return _requireParsed(ExpertRoutineDetail.fromJson(_mapBodyOf(response)));
      });

  /// 일과관리 맨 앞에 넣는다 (묶음 없이)
  Future<ExpertRoutineImportResult> importToLibrary(
    String expertRoutineId, {
    required String profileId,
  }) => _call('importToLibrary', () async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/expert-routines/${Uri.encodeComponent(expertRoutineId)}/import',
      data: {'profileId': profileId},
      options: _accountLevelOptions,
    );
    final body = _mapBodyOf(response);
    final routineId = TalkJson.nonEmptyText(body['routineId']);
    final importedProfileId = TalkJson.nonEmptyText(body['profileId']);
    if (routineId == null || importedProfileId == null) {
      throw const FormatException('malformed response');
    }
    return (routineId: routineId, profileId: importedProfileId);
  });

  /// 로그 + 모든 실패를 [AppFailure] 로 통일
  Future<T> _call<T>(String operation, Future<T> Function() body) async {
    try {
      return await logged('ExpertRoutineRepository', operation, body);
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

final expertRoutineRepositoryProvider = Provider<ExpertRoutineRepository>(
  (ref) => ExpertRoutineRepository(ref.watch(dioProvider)),
);
