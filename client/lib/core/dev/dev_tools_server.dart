part of 'dev_tools_overlay.dart';

/// 로컬 서버 기본 주소 2개 (시뮬레이터는 Mac 자신, 안드로이드 에뮬레이터는 10.0.2.2 가 Mac)
const _localSimulatorApiBaseUrl = 'http://localhost:8080';
const _localEmulatorApiBaseUrl = 'http://10.0.2.2:8080';

/// 서버 바꾸기: 운영·로컬·최근·직접 입력 > 지금 서버 로그아웃 > 서버 캐시 비움 > 저장 > 앱 다시 띄우기
class _ServerView extends ConsumerStatefulWidget {
  const _ServerView({required this.onRestartApp});

  final void Function(BuildContext context) onRestartApp;

  @override
  ConsumerState<_ServerView> createState() => _ServerViewState();
}

class _ServerViewState extends ConsumerState<_ServerView> {
  final _customUrlController = TextEditingController();
  List<String> _recentUrls = const [];
  String? _rejectReason;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentUrls();
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentUrls() async {
    final store = await DevServerStore.open();
    if (!mounted) return;
    setState(() => _recentUrls = store.recentApiBaseUrls);
  }

  @override
  Widget build(BuildContext context) {
    final current = AppConfig.apiBaseUrl;
    final presets = <(String, String)>[
      ('운영 (빌드 기본값)', AppConfig.defaultApiBaseUrl),
      ('로컬 · iOS 시뮬레이터', _localSimulatorApiBaseUrl),
      ('로컬 · 안드로이드 에뮬레이터', _localEmulatorApiBaseUrl),
    ];
    final presetUrls = presets.map((preset) => preset.$2).toSet();
    final otherRecentUrls = _recentUrls.where((url) => !presetUrls.contains(url));

    return ListView(
      shrinkWrap: true,
      children: [
        _Message('지금: $current\n'
            '바꾸면 지금 서버에서 로그아웃하고 앱을 처음 화면부터 다시 띄웁니다.'),
        for (final (label, url) in presets)
          _ChoiceTile(
            label: label,
            subtitle: url,
            isSelected: url == current,
            onTap: _isSwitching ? null : () => _switchTo(url),
          ),
        for (final url in otherRecentUrls)
          _ChoiceTile(
            label: '최근',
            subtitle: url,
            isSelected: url == current,
            onTap: _isSwitching ? null : () => _switchTo(url),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _customUrlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: '직접 입력',
              hintText: 'http://192.168.0.10:8080',
              errorText: _rejectReason,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _switchToCustomUrl(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: FilledButton(
            onPressed: _isSwitching ? null : _switchToCustomUrl,
            child: Text(_isSwitching ? '바꾸는 중…' : '이 주소로 바꾸기'),
          ),
        ),
        const _Message(
          '실제 기기에서 Mac 로컬 서버: Mac 의 와이파이 IP 주소 (같은 와이파이)\n'
          '로컬 서버 실행: SPRING_PROFILES_ACTIVE=dev, '
          '테스트 계정은 ELUM_AUTH_LEGACY_PASSWORD_ENABLED=true 로 띄움',
        ),
      ],
    );
  }

  void _switchToCustomUrl() {
    final normalized = normalizeDevApiBaseUrl(_customUrlController.text);
    setState(() => _rejectReason = normalized.rejectReason);
    final url = normalized.url;
    if (url != null) _switchTo(url);
  }

  Future<void> _switchTo(String url) async {
    if (url == AppConfig.apiBaseUrl) return;
    setState(() => _isSwitching = true);

    // 지금 서버 로그아웃 (푸시 토큰 해제 포함, 서버가 꺼져 있어도 로컬은 지움)
    final authRepository = ref.read(authRepositoryProvider);
    if (authRepository.hasSession) await authRepository.logout();

    // 서버마다 다른 캐시 비움 (시간값, 약관)
    final storage = ref.read(localStorageProvider);
    await storage.setCachedClientTuningJson('');
    await storage.setCachedConsentJson('');
    AppConfig.resetTuning();

    // 기본 주소면 지정을 지움 (다음 빌드의 .env 를 따라가게)
    final savedUrl = url == AppConfig.defaultApiBaseUrl ? null : url;
    final store = await DevServerStore.open();
    await store.saveApiBaseUrl(savedUrl);
    AppConfig.overrideApiBaseUrl(savedUrl);
    AppLogger.info('[dev server] switched : -> $url');

    if (!mounted) return;
    widget.onRestartApp(context);
  }
}

/// 테스트 계정: 새로 만들기·저장한 계정으로 로그인 (운영이 아닌 서버, 서버 주소별 저장)
class _TestAccountView extends ConsumerStatefulWidget {
  const _TestAccountView({required this.onClose, required this.onNavigate});

  final VoidCallback onClose;
  final void Function(String route) onNavigate;

  @override
  ConsumerState<_TestAccountView> createState() => _TestAccountViewState();
}

class _TestAccountViewState extends ConsumerState<_TestAccountView> {
  // 테스트 계정 비밀번호 길이
  static const _passwordLength = 16;
  static const _passwordCharacters = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  DevServerStore? _store;
  String? _message;
  bool _isError = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    DevServerStore.open().then((store) {
      if (mounted) setState(() => _store = store);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isProductionApiServer) {
      return const _Message('운영 서버는 테스트 계정 로그인을 열지 않습니다.\n'
          '서버 바꾸기에서 로컬·테스트 서버를 먼저 고르세요.');
    }
    final accounts = _store?.testAccountsFor(AppConfig.apiBaseUrl) ?? const <DevTestAccount>[];
    final message = _message;
    return ListView(
      shrinkWrap: true,
      children: [
        _Message('서버: ${AppConfig.apiBaseUrl}'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: _isBusy ? null : _createAndSignIn,
            icon: const Icon(Icons.person_add_alt),
            label: Text(_isBusy ? '처리 중…' : '새 테스트 계정 만들고 로그인'),
          ),
        ),
        if (message != null) _Message(message, isError: _isError),
        if (accounts.isNotEmpty) const _Section('이 서버에 만든 계정'),
        for (final account in accounts)
          ListTile(
            title: Text(account.username),
            subtitle: Text(
              '만든 때 ${account.createdAt.toLocal().toString().substring(0, 16)}',
              style: const TextStyle(fontSize: 12),
            ),
            onTap: _isBusy ? null : () => _signIn(account),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, semanticLabel: '목록에서 지우기'),
              onPressed: () async {
                await _store?.removeTestAccount(AppConfig.apiBaseUrl, account.username);
                if (mounted) setState(() {});
              },
            ),
          ),
      ],
    );
  }

  // 아이디 test{MMddHHmmss} + 무작위 비밀번호 > 가입 > 목록 저장 > 로그인
  Future<void> _createAndSignIn() async {
    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final account = DevTestAccount(
      username: 'test${twoDigits(now.month)}${twoDigits(now.day)}'
          '${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}',
      password: _randomPassword(),
      createdAt: now,
    );
    setState(() => _isBusy = true);
    final failure = await ref
        .read(authRepositoryProvider)
        .signUpTestAccount(username: account.username, password: account.password);
    if (!mounted) return;
    if (failure != null) {
      _showResult(_signUpFailureText(failure), isError: true);
      return;
    }
    await _store?.addTestAccount(AppConfig.apiBaseUrl, account);
    await _signIn(account);
  }

  // 로그인 > 이전 계정 메모리 정리 > 소셜 로그인과 같은 갈래로 이동
  Future<void> _signIn(DevTestAccount account) async {
    setState(() => _isBusy = true);
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithTestAccount(username: account.username, password: account.password);
    if (!mounted) return;
    final loginController = ref.read(loginControllerProvider);
    final route = switch (result.outcome) {
      AuthOutcome.consentRequired => Routes.consent,
      AuthOutcome.onboarding => Routes.roleSelect,
      AuthOutcome.home => await loginController.hasPin()
          ? Routes.guardian
          : '${Routes.guardianPinChange}?from=login',
      _ => null,
    };
    if (!mounted) return;
    if (route == null) {
      final failure = result.failure;
      _showResult(
        '로그인 실패: ${result.outcome.name}${failure == null ? '' : ' · ${_describeFailure(failure)}'}',
        isError: true,
      );
      return;
    }
    await loginController.resetPreviousAccount();
    if (result.outcome != AuthOutcome.home) loginController.forgetPreviousChild();
    AppLogger.info('[dev account] signed in : ${account.username} -> $route');
    widget.onClose();
    widget.onNavigate(route);
  }

  // 가입 경로가 없는 서버(운영 프로파일, 설정 꺼짐)는 404 또는 서버 오류로 옴 > 켜는 방법 함께 안내
  String _signUpFailureText(AppFailure failure) =>
      '가입 실패: ${_describeFailure(failure)}\n'
      '테스트 계정이 꺼진 서버일 수 있습니다. '
      '서버를 ELUM_AUTH_LEGACY_PASSWORD_ENABLED=true 로 띄우세요 (운영 프로파일 불가).';

  void _showResult(String message, {required bool isError}) => setState(() {
    _message = message;
    _isError = isError;
    _isBusy = false;
  });

  static String _randomPassword() {
    final random = Random.secure();
    return List.generate(
      _passwordLength,
      (_) => _passwordCharacters[random.nextInt(_passwordCharacters.length)],
    ).join();
  }
}
