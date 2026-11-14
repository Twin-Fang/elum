/// 보호자 가이드 팁 5개: 사이트 안내 글 주소 조각(slug, site/site_config.py `GUIDE_SLUGS`)
/// 팁 추가: 값 한 줄 + ARB 제목·설명 + 팁 카드의 그림·문구 switch (빠지면 컴파일 에러)
enum GuideTip {
  actionCards('action-cards'),
  makeActionCards('make-action-cards'),
  caregiverRole('caregiver-role'),
  taskAnalysis('task-analysis'),
  rewards('rewards');

  const GuideTip(this.slug);

  /// 사이트 글 주소 조각 (모든 언어 같음). 닫은 기록의 키로도 씀
  final String slug;
}

/// 팁을 보일 보호자 화면 3곳: 자리별 후보 순서 (앞에서부터 안 닫은 첫 팁 하나만 보임)
/// 이룸이 화면에는 두지 않음
enum GuideTipPlacement {
  /// 보호자 홈 오늘 일과와 지난 일과 사이: 처음 쓰는 보호자가 읽을 순서
  guardianHome([GuideTip.actionCards, GuideTip.caregiverRole, GuideTip.rewards]),

  /// 일과 만들기 입력: 한 줄 쓰는 요령 > 단계 나누기
  routineInput([GuideTip.makeActionCards, GuideTip.taskAnalysis]),

  /// 보상 정하기
  rewardSetup([GuideTip.rewards]);

  const GuideTipPlacement(this.candidates);

  final List<GuideTip> candidates;

  /// 닫은 slug 를 뺀 첫 팁. 다 닫았으면 null
  GuideTip? firstVisibleTip(Set<String> dismissedSlugs) {
    for (final tip in candidates) {
      if (!dismissedSlugs.contains(tip.slug)) return tip;
    }
    return null;
  }
}
