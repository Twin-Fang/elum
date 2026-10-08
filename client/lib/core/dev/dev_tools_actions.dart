part of 'dev_tools_overlay.dart';

/// 앱 언어 강제 — 휴대폰 언어를 바꾸지 않고 다른 언어 화면을 본다.
///
/// 값은 메모리에만 있다. 앱을 다시 켜면 휴대폰 언어로 돌아간다([DevLocaleOverrideNotifier]).
class _LocaleView extends ConsumerWidget {
  const _LocaleView();

  /// 각 언어가 자기 이름으로 적힌다 — 어느 언어가 켜져 있어도 찾을 수 있게.
  static const _names = {
    'ko': '한국어',
    'en': 'English',
    'ja': '日本語',
    'zh': '简体中文',
    'es': 'Español',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forced = ref.watch(devLocaleOverrideProvider);
    final notifier = ref.read(devLocaleOverrideProvider.notifier);
    return ListView(
      shrinkWrap: true,
      children: [
        _LocaleTile(
          label: '휴대폰 언어 따르기',
          selected: forced == null,
          onTap: () => notifier.set(null),
        ),
        for (final l in supportedAppLocales)
          _LocaleTile(
            label: _names[l.languageCode] ?? l.languageCode,
            selected: forced == l,
            onTap: () => notifier.set(l),
          ),
      ],
    );
  }
}

class _LocaleTile extends StatelessWidget {
  const _LocaleTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Radio 의 groupValue·onChanged 는 deprecated 라 체크 아이콘으로 고른 줄을 표시한다
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}

/// 회원삭제 확인 — 실수로 눌러 계정이 날아가지 않도록 한 단계 둔다.
///
/// `showDialog`를 쓰지 않는다. 이 위젯도 Navigator보다 위에 있어
/// 다이얼로그를 띄울 수 없다. 시트 안에서 화면만 바꾼다.
class _ConfirmResetView extends ConsumerWidget {
  const _ConfirmResetView({
    required this.onCancel,
    required this.onDone,
    required this.onNavigate,
  });

  final VoidCallback onCancel;
  final VoidCallback onDone;
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '계정과 저장된 호칭·목표·캐릭터·PIN이\n모두 지워집니다.\n같은 이름을 넣어도 새로 시작합니다.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    // 서버 계정까지 지운다. 실패하면 로컬도 그대로 남는다 (이슈 #187) —
                    // 개발 도구라 여기서는 결과를 따지지 않고 로그인으로 보낸다.
                    await ref.read(authRepositoryProvider).deleteAccount();
                    // 메모리 상태도 비운다 — 저장소만 지우면 화면이 이전 값을 들고 있다.
                    // routineFlow(방금 만든 일과)·myRoutines(서버 조회 캐시)를 함께 비우지
                    // 않으면 재가입 후 홈에 이전 계정 일과가 그대로 노출된다 (이슈 #91).
                    ref.read(routineFlowProvider.notifier).reset();
                    ref.refreshRoutines();
                    ref.invalidate(onboardingProvider);
                    if (!context.mounted) return;
                    onDone();
                    // 계정이 사라졌으니 로그인부터 다시 한다.
                    onNavigate(Routes.login);
                  },
                  child: const Text('회원삭제'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 로그아웃 확인 — 계정은 남기고 세션만 끊는다 (이슈 #219).
///
/// 회원삭제는 되돌릴 수 없어 테스트 중 계정을 계속 새로 만들어야 했다.
/// 로그인 흐름만 다시 밟고 싶을 때 쓴다.
class _ConfirmLogoutView extends ConsumerWidget {
  const _ConfirmLogoutView({
    required this.onCancel,
    required this.onDone,
    required this.onNavigate,
  });

  final VoidCallback onCancel;
  final VoidCallback onDone;
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '계정은 그대로 남습니다.\n세션만 끊고 로그인 화면으로 갑니다.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onCancel, child: const Text('취소')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).logout();
                    // 메모리에 남은 이전 계정 값도 비운다 (회원삭제와 같은 이유, 이슈 #91)
                    ref.read(routineFlowProvider.notifier).reset();
                    ref.refreshRoutines();
                    ref.invalidate(onboardingProvider);
                    if (!context.mounted) return;
                    onDone();
                    onNavigate(Routes.login);
                  },
                  child: const Text('로그아웃'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
