import '../logger/app_logger.dart';
import 'app_failure.dart';

/// 저장소 호출의 로그(호출·완료·실패)와 예외 변환을 한곳에서 맡는다.
///
/// 로그에는 저장소·메서드 이름만 남긴다. 요청 본문·토큰 같은 원문은 넘기지 않는다.
/// [describe] 는 완료 로그에 찍을 요약이다 — 값 자체가 아니라 건수·상태 같은 요약만 돌려준다.

/// 예외를 [Attempt.failed] 로 바꿔 돌려준다. 호출부에 예외가 올라가지 않는다.
///
/// [body] 안에서 [AppFailure] 를 던지면 그대로 실패 값이 된다(응답 모양 검증 등).
Future<Attempt<T>> guarded<T>(
  String repo,
  String op,
  Future<T> Function() body, {
  String Function(T value)? describe,
}) async {
  try {
    final value = await _run(repo, op, body, describe);
    return Attempt.ok(value);
  } catch (e) {
    return Attempt.failed(AppFailure.of(e));
  }
}

/// 같은 로그를 남기고 예외는 그대로 다시 던진다. 호출부가 직접 처리·변환한다.
Future<T> logged<T>(
  String repo,
  String op,
  Future<T> Function() body, {
  String Function(T value)? describe,
}) =>
    _run(repo, op, body, describe);

Future<T> _run<T>(
  String repo,
  String op,
  Future<T> Function() body,
  String Function(T value)? describe,
) async {
  AppLogger.repositoryCall(repo, op);
  try {
    final value = await body();
    AppLogger.repositorySuccess(repo, op, describe?.call(value));
    return value;
  } catch (e) {
    AppLogger.repositoryError(repo, op, e);
    rethrow;
  }
}
