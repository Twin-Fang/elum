import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 이 기기가 보호자 푸시를 더 받지 않게 정리하는 일 (서버 토큰 해제 > 기기 토큰 삭제, 실패해도 던지지 않음)
typedef PushUnregister = Future<void> Function();

/// 로그아웃·회원삭제·이룸이 기기 전환 직전에 부르는 연결 고리
/// 인증·연결 data 가 알림 기능을 import 하지 못하므로 core 에 두고, 실제 구현은 main 이 끼움
final pushUnregisterProvider = Provider<PushUnregister>((ref) => () async {});
