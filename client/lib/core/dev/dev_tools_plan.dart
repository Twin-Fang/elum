part of 'dev_tools_overlay.dart';

/// 요금제 흉내 줄: 서버 값 · Free · Pro 를 메뉴에서 바로 고름 (이 기기 화면 판정만, 서버 권한·크레딧은 그대로)
///
/// 값은 메모리에만 있다. 앱을 다시 켜면 서버 값으로 돌아간다([DevPlanOverrideNotifier]).
class _PlanOverrideRow extends ConsumerWidget {
  const _PlanOverrideRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(devPlanOverrideProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.workspace_premium_outlined, size: 18, color: Color(0xFF3A3A3C)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '요금제 흉내',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _DevPalette.title),
                ),
              ),
              if (current != DevPlanOverride.server) const _ValueChip('흉내 중', isChanged: true),
            ],
          ),
          const SizedBox(height: 10),
          _SegmentedPicker<DevPlanOverride>(
            options: [for (final planOverride in DevPlanOverride.values) (planOverride, planOverride.label)],
            selected: current,
            onSelected: ref.read(devPlanOverrideProvider.notifier).set,
          ),
        ],
      ),
    );
  }
}

/// 결제 화면 켜기 줄: 빌드 설정(`ELUM_IAP_ENABLED`)·서버 판매 스위치가 꺼져 있어도 요금제 화면·Pro 알아보기를 엶
class _StoreForcedRow extends ConsumerWidget {
  const _StoreForcedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isServerSellingOpen = ref.watch(isServerStoreSellingOpenProvider);
    // 지금 판매 판정 재료 2개: 빌드 설정(하드 킬) · 서버 판매 스위치 (#1132)
    return _SwitchTile(
      icon: Icons.storefront_outlined,
      label: '결제 화면 켜기',
      subtitle:
          '빌드 설정 ${AppConfig.isInAppPurchaseEnabled ? '켜짐' : '꺼짐'} · '
          '서버 판매 ${isServerSellingOpen ? '켜짐' : '꺼짐'}. 실제 결제는 Sandbox·라이선스 테스트 계정 필요',
      isOn: ref.watch(devPlanStoreForcedProvider),
      onChanged: ref.read(devPlanStoreForcedProvider.notifier).set,
    );
  }
}

/// 크레딧 판매 화면 켜기 줄: 서버 판매 스위치가 꺼져 있어도 내 크레딧의 꾸러미 구역을 보임
class _CreditPackSaleForcedRow extends ConsumerWidget {
  const _CreditPackSaleForcedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SwitchTile(
      icon: Icons.confirmation_number_outlined,
      label: '크레딧 판매 화면 켜기',
      subtitle: '서버 판매 스위치와 무관하게 꾸러미 구역 표시. 스토어 값이 없으면 값 오류가 보임',
      isOn: ref.watch(devCreditPackSaleForcedProvider),
      onChanged: ref.read(devCreditPackSaleForcedProvider.notifier).set,
    );
  }
}

/// Pro 미리 보기 켜기 줄: 스토어 상품 없이도 판매 중으로 보고 Free 화면에 Pro 미리 보기를 띄움
class _ProTeaserForcedRow extends ConsumerWidget {
  const _ProTeaserForcedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SwitchTile(
      icon: Icons.auto_awesome_outlined,
      label: 'Pro 미리 보기 켜기',
      subtitle: '`Free 처럼`과 함께 켜기. 요금제 화면까지 열려면 결제 화면 켜기도 켜기',
      isOn: ref.watch(devProTeaserForcedProvider),
      onChanged: ref.read(devProTeaserForcedProvider.notifier).set,
    );
  }
}
