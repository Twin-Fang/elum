part of 'dev_tools_overlay.dart';

/// 요금제 흉내 — 서버 요금제를 바꾸지 않고 이 기기 화면만 Free·Pro 로 본다
///
/// 값은 메모리에만 있다. 앱을 다시 켜면 서버 값으로 돌아간다([DevPlanOverrideNotifier]).
/// 아래 `결제 화면 켜기` 는 `ELUM_IAP_ENABLED` 가 꺼진 빌드에서 결제 화면·진입점을 연다.
class _PlanOverrideView extends ConsumerWidget {
  const _PlanOverrideView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(devPlanOverrideProvider);
    final notifier = ref.read(devPlanOverrideProvider.notifier);
    final isStoreForced = ref.watch(devPlanStoreForcedProvider);
    return ListView(
      shrinkWrap: true,
      children: [
        for (final value in DevPlanOverride.values)
          _LocaleTile(
            label: value.label,
            selected: current == value,
            onTap: () => notifier.set(value),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            '화면 판정만 바뀐다 (카드 내보내기 워터마크·테마, 주간 리포트 입구 등). '
            '서버 크레딧·결제·권한은 그대로다.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        ListTile(
          title: Text(
            AppConfig.isInAppPurchaseEnabled
                ? '결제 화면 켜기 (빌드 설정으로 이미 켜짐)'
                : '결제 화면 켜기',
          ),
          trailing: Switch(
            value: isStoreForced || AppConfig.isInAppPurchaseEnabled,
            onChanged: AppConfig.isInAppPurchaseEnabled
                ? null
                : (isOn) =>
                      ref.read(devPlanStoreForcedProvider.notifier).set(isOn),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            '스토어 상품을 불러와 요금제 화면·Pro 알아보기를 연다. '
            '실제 결제는 Sandbox·라이선스 테스트 계정과 서버 스토어 설정이 있어야 끝난다.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
