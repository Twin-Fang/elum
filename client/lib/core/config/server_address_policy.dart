/// 운영 API 주소 규칙: https, 허용 도메인 2개, 포트·경로·쿼리 없음 (#831)
/// 서버 `ServerAddressPolicy.ALLOWED_API_HOSTS` 와 같은 목록 (서버 CrossStackContractTest 가 대조)
abstract final class ServerAddressPolicy {
  // 운영 도메인 2개: 기존 서버(친구 NAS), 새 서버(내 NAS)
  static const allowedApiHosts = <String>{
    'api.elum.chuseok22.com',
    'api.elum.suhsaechan.kr',
  };

  static const _requiredScheme = 'https';

  /// 허용 운영 도메인인가 (대소문자 무시, 정확히 같은 호스트만)
  static bool isAllowedApiHost(String host) =>
      allowedApiHosts.contains(host.toLowerCase());

  /// 허용 운영 주소 > `https://{호스트}` (끝 `/` 하나 허용), 아니면 null. 어떤 입력에도 던지지 않음
  static String? toAllowedApiBaseUrl(String? raw) {
    final trimmedUrl = raw?.trim() ?? '';
    if (trimmedUrl.isEmpty) return null;
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null) return null;
    final path = uri.path;
    final isAllowed = uri.scheme.toLowerCase() == _requiredScheme &&
        isAllowedApiHost(uri.host) &&
        !uri.hasPort &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (path.isEmpty || path == '/');
    return isAllowed ? '$_requiredScheme://${uri.host.toLowerCase()}' : null;
  }
}
