import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../domain/routine_memory.dart';

/// 내 AI 메모리 API (`/api/routine-memory`). 고른 이룸이는 `X-Profile-Id` 로 실린다.
/// 규칙 글은 보호자가 쓴 글이라 로그에 남기지 않는다 (개수만). 실패는 [AppFailure] 로 던진다.
class RoutineMemoryRepository {
  RoutineMemoryRepository(this._dio);

  final Dio _dio;

  static const _path = '/api/routine-memory';

  Future<RoutineMemory> fetch() => _call('fetch', () async => RoutineMemory.fromJson(_bodyOf(await _dio.get<Map<String, dynamic>>(_path))));

  /// 규칙 직접 적기
  Future<void> addRule(String text) => _call('addRule', () async {
    await _dio.post<void>('$_path/rules', data: {'text': text});
  });

  /// 켜기(ACTIVE) · 끄기(OFF) · 관찰 중에서 지금 적용(ACTIVE)
  Future<void> setRuleStatus(String ruleId, MemoryRuleStatus status) => _call('setRuleStatus', () async {
    await _dio.patch<void>('$_path/rules/${Uri.encodeComponent(ruleId)}', data: {'status': status.wire});
  });

  /// 직접 적은 규칙 글 고치기
  Future<void> editRuleText(String ruleId, String text) => _call('editRuleText', () async {
    await _dio.patch<void>('$_path/rules/${Uri.encodeComponent(ruleId)}', data: {'text': text});
  });

  Future<void> deleteRule(String ruleId) => _call('deleteRule', () async {
    await _dio.delete<void>('$_path/rules/${Uri.encodeComponent(ruleId)}');
  });

  /// 고친 내용에서 자동으로 찾기 켜기·끄기
  Future<void> setEnabled(bool isEnabled) => _call('setEnabled', () async {
    await _dio.patch<void>('$_path/enabled', data: {'enabled': isEnabled});
  });

  /// 메모리 모두 지우기
  Future<void> clear() => _call('clear', () async {
    await _dio.delete<void>(_path);
  });

  /// 방금 고쳐 보낸 일과에서 찾은 수정 (계산 중이면 PENDING)
  Future<MemoryObservations> fetchObservations(String routineId) => _call('fetchObservations', () async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_path/observations',
      queryParameters: {'routineId': routineId},
    );
    return MemoryObservations.parse(response.data);
  });

  /// 내보내기 JSON (`elum.routine-memory.v1`) 글자 그대로
  Future<String> exportJson() => _call('exportJson', () async {
    final response = await _dio.get<Map<String, dynamic>>('$_path/export');
    return jsonEncode(response.data ?? const <String, dynamic>{});
  });

  Future<T> _call<T>(String operation, Future<T> Function() body) async {
    try {
      return await logged('RoutineMemoryRepository', operation, body);
    } catch (e) {
      throw AppFailure.of(e);
    }
  }

  Map<String, dynamic> _bodyOf(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) throw const FormatException('empty response');
    return body;
  }
}

final routineMemoryRepositoryProvider = Provider<RoutineMemoryRepository>(
  (ref) => RoutineMemoryRepository(ref.watch(dioProvider)),
);
