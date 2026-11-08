part of 'dev_tools_overlay.dart';

// 화면 쪽 값 읽기 (provider·라우터): 상태 복사·전체 값 보기·지금 상태 카드가 함께 씀

/// 전체 덤프 > 임시 파일 > 공유 시트. 결과 (안내 문구, 실패 여부)
Future<(String, bool)> _exportFullDump(BuildContext context, WidgetRef ref, String? Function() currentLocation) async {
  // 아이패드 공유 팝오버 기준 (await 전에 잡음)
  final origin = shareOriginOf(context);
  try {
    final text = await DevStateDump.full(context: context, liveSections: _readLiveSections(ref, currentLocation));
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${DevStateDump.fileName()}');
    await file.writeAsString(text);
    // 사용자가 공유 시트를 닫아도 예외 아님
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'elum 디버그 덤프', sharePositionOrigin: origin),
    );
    return ('내보냈어요: ${file.path.split('/').last}', false);
  } catch (error) {
    return ('내보내지 못했어요: $error', true);
  }
}

/// provider·라우터에서 읽는 칸 5개: 지금 화면, 계정, 요금제, 크레딧, 이 기기 흉내
List<DevStateSection> _readLiveSections(WidgetRef ref, String? Function() currentLocation) {
  final member = ref.read(memberProvider).value;
  final storage = ref.read(localStorageProvider);
  final planAccess = ref.read(planAccessProvider);
  final subscription = member?.subscription;
  final credit = ref.read(creditSummaryProvider);
  final locale = ref.read(devLocaleOverrideProvider);
  return [
    DevStateSection('지금 화면', {'경로': _readLocation(currentLocation) ?? '(모름)'}),
    DevStateSection('계정', {
      '로그인': _accountLabel(member, storage),
      '회원 id': member?.id ?? '(회원 정보 없음)',
      '이룸이 수': member == null ? '-' : '${member.profiles.length}명',
    }),
    DevStateSection('요금제', {
      '서버 권한': member == null ? '(회원 정보 없음)' : (member.entitlements.isPro ? 'Pro' : 'Free'),
      '화면 판정': planAccess.isPro ? 'Pro' : 'Free',
      '요금제 흉내': ref.read(devPlanOverrideProvider).label,
      '구독': subscription == null ? '(없음)' : _subscriptionLabel(subscription),
      '결제 화면': AppConfig.isInAppPurchaseEnabled
          ? '켜짐 (빌드 설정)'
          : (ref.read(devPlanStoreForcedProvider) ? '켜짐 (개발자 도구)' : '꺼짐'),
      '서버 판매 스위치': ref.read(isServerStoreSellingOpenProvider) ? '켜짐' : '꺼짐',
      'Pro 미리 보기 강제': ref.read(devProTeaserForcedProvider) ? '켜짐 (개발자 도구)' : '꺼짐',
      'Pro 구매 가능 판정': planAccess.canPurchasePro ? '예' : '아니오',
    }),
    DevStateSection('크레딧', {'이번 주': _creditLabel(credit)}),
    DevStateSection('이 기기 흉내', {
      '앱 상태': DevSimulation.appStatus.value.label,
      '요청 실패': DevSimulation.networkFault.value.label,
      '언어 강제': locale == null ? '끔 (기기 언어)' : locale.toLanguageTag(),
      '온보딩 건너뛰기': AppConfig.skipOnboarding ? '켜짐' : '꺼짐',
    }),
  ];
}

/// 구독 한 줄: 결제처 · 상품 · 만료 · 자동 갱신 (· 유예 중)
String _subscriptionLabel(MemberSubscription subscription) {
  final expiresAt = subscription.expiresAt;
  return [
    subscription.source.apiValue,
    subscription.productId ?? '-',
    '만료 ${expiresAt == null ? '-' : DevStateReport.formatLocalTime(expiresAt)}',
    '자동 갱신 ${subscription.willAutoRenew ?? '-'}',
    if (subscription.isInGracePeriod) '유예 중',
  ].join(' · ');
}

/// 라우터 위치 (못 읽으면 null)
String? _readLocation(String? Function() currentLocation) {
  try {
    return currentLocation();
  } catch (_) {
    return null;
  }
}

/// 계정 한 줄: 로그인 제공자 · 역할 · 회원 id 앞 8자
String _accountLabel(Member? member, LocalStorage storage) {
  final providerName = member?.account?.signInProvider?.name ?? storage.lastLoginProvider;
  // 로그인 제공자 > 한글 이름 (모르는 값은 그대로)
  final provider = switch (providerName) {
    'kakao' => '카카오',
    'naver' => '네이버',
    'google' => '구글',
    'apple' => '애플',
    _ => providerName,
  };
  final role = switch (storage.selectedRole) {
    'guardian' => '보호자',
    'elumi' => '이룸이',
    _ => '역할 없음',
  };
  final memberId = member?.id;
  return [
    provider ?? '로그인 안 됨',
    role,
    if (memberId != null) memberId.substring(0, memberId.length < 8 ? memberId.length : 8),
  ].join(' · ');
}

/// 요금제 한 줄: 서버 값 (+ 흉내)
String _planLabel(Member? member, DevPlanOverride planOverride) {
  final serverPlan = member == null ? '모름' : (member.entitlements.isPro ? 'Pro' : 'Free');
  return planOverride == DevPlanOverride.server ? '$serverPlan (서버)' : '$serverPlan (서버) → ${planOverride.label}';
}

/// 크레딧 한 줄: 남음 / 주간 지급 (보너스·사용·예약)
String _creditLabel(AsyncValue<CreditSummary> credit) {
  return credit.when(
    data: (summary) => summary.enabled
        ? '남음 ${summary.available} / 주 ${summary.weeklyGrant} '
              '(보너스 ${summary.bonus} · 사용 ${summary.used} · 예약 ${summary.reserved})'
        : '크레딧 꺼짐 (서버 설정)',
    loading: () => '불러오는 중…',
    error: (error, _) => '못 읽음: ${error is AppFailure ? _describeFailure(error) : error}',
  );
}

/// provider 로 켜는 흉내 이름 (요금제·결제 화면·Pro 미리 보기·언어). 앱 상태·요청 실패는 [DevSimulation.activeLabels]
List<String> _providerSimulationLabels({
  required DevPlanOverride planOverride,
  required bool isStoreForced,
  required bool isTeaserForced,
  required Locale? locale,
}) {
  return [
    if (planOverride != DevPlanOverride.server) '요금제 ${planOverride.label}',
    if (isStoreForced) '결제 화면 켬',
    if (isTeaserForced) 'Pro 미리 보기 켬',
    if (locale != null) '언어 ${locale.toLanguageTag()}',
  ];
}
