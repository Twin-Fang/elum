import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../logger/app_logger.dart';

/// 이 휴대폰의 기기 이름(모델명)을 읽는다 — 이룸이 휴대폰을 연결할 때 보호자 화면에 보이려고 서버로 보낸다.
///
/// **모델명만 읽는다.** 사용자가 정한 기기 이름("OO의 iPhone")과 고유 식별자는 개인정보라 읽지 않는다.
/// 부가 정보라서 읽기에 실패하거나 오래 걸리면 null 을 돌려주고, 호출한 쪽은 이름 없이 연결한다.
typedef DeviceNameReader = Future<String?> Function();

/// 기기 정보를 기다리는 한도 — 연결 자체가 이 값에 막히면 안 된다.
const _readTimeout = Duration(seconds: 2);

/// 서버가 40자까지 받으므로 같은 길이로 맞춘다.
const _maxLength = 40;

Future<String?> readDeviceName() async {
  try {
    final plugin = DeviceInfoPlugin();
    final String? raw;
    if (Platform.isIOS) {
      final info = await plugin.iosInfo.timeout(_readTimeout);
      // modelName 은 `iPhone 16` 처럼 사람이 읽는 이름이다. 비면 일반 모델 종류(`iPhone`)로 대신한다.
      raw = info.modelName.trim().isNotEmpty ? info.modelName : info.model;
    } else if (Platform.isAndroid) {
      final info = await plugin.androidInfo.timeout(_readTimeout);
      raw = androidDisplayName(info.manufacturer, info.model);
    } else {
      raw = null;
    }
    return normalizeDeviceName(raw);
  } catch (e) {
    // 지원하지 않는 플랫폼·플러그인 오류·시간 초과 모두 같다 — 이름 없이 연결한다.
    AppLogger.error('기기 이름 읽기', e);
    return null;
  }
}

/// 안드로이드는 제조사와 모델을 합친다. 모델이 이미 제조사 이름으로 시작하면 겹쳐 쓰지 않는다.
String? androidDisplayName(String manufacturer, String model) {
  final maker = manufacturer.trim();
  final name = model.trim();
  if (name.isEmpty) return maker.isEmpty ? null : _capitalize(maker);
  if (maker.isEmpty || name.toLowerCase().startsWith(maker.toLowerCase())) {
    return name;
  }
  return '${_capitalize(maker)} $name';
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// 제어 문자를 빼고 공백을 정리해 길이를 맞춘다. 비면 null.
String? normalizeDeviceName(String? raw) {
  if (raw == null) return null;
  final cleaned = raw
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return null;
  final runes = cleaned.runes.toList();
  if (runes.length <= _maxLength) return cleaned;
  return String.fromCharCodes(runes.take(_maxLength)).trim();
}
