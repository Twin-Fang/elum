import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../application/onboarding_notifier.dart';

/// Figma `온보딩_맞춤설정완료`(204:1042~1113) — 온보딩 결과를 저장하며
/// 서비스 원칙 5개를 순차로 안내하는 전환 화면.
///
/// 1~4단계는 자동으로 넘어가고, 마지막 단계에서만 CTA `첫 일과 만들기`가 떠서
/// 보호자가 직접 눌러 홈으로 진입한다. 자동 전환으로 문구를 놓쳐도
/// 마지막 안내(개인정보 원칙)만큼은 읽고 넘어가게 하기 위함이다.
class SetupDoneScreen extends ConsumerStatefulWidget {
  const SetupDoneScreen({super.key});

  /// 문구 하나가 화면에 머무는 시간.
  ///
  /// 저장은 로컬이라 대개 즉시 끝난다. 그대로 넘기면 화면이 깜빡이기만 하고
  /// 무슨 일이 있었는지 보호자가 읽을 틈이 없다.
  static const holdDuration = Duration(milliseconds: 1600);

  /// Figma 변형 5개(204:1045/1095/1102/1109/1116)의 문구. 줄바꿈도 디자인 값이다.
  static const messages = [
    '준비물은 눈에 보이는\n체크리스트로 보여드려요',
    '평소와 달라지는 상황은\n미리 알려드려요',
    '한 카드에는\n한 행동만 담아요',
    '보호자가 확인한 뒤\n아이에게 전달해요',
    '장애 유형이나 진단명 없이\n선택한 도움 방식만 활용해요',
  ];

  @override
  ConsumerState<SetupDoneScreen> createState() => _SetupDoneScreenState();
}

class _SetupDoneScreenState extends ConsumerState<SetupDoneScreen> {
  Timer? _timer;

  /// 현재 보여주는 문구 인덱스 (0 ~ messages.length-1)
  int _step = 0;

  bool get _isLastStep => _step == SetupDoneScreen.messages.length - 1;

  @override
  void initState() {
    super.initState();
    // 저장 실패가 데모를 막으면 안 된다(docs 원칙 6번). notifier가 예외를
    // 삼키므로 화면은 저장 완료를 기다리지 않고 안내를 진행한다.
    unawaited(ref.read(onboardingProvider.notifier).complete());
    _scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 다음 문구로의 자동 전환을 예약한다. 마지막 단계는 CTA 탭으로만 진행한다.
  void _scheduleNext() {
    if (_isLastStep) return;

    _timer = Timer(SetupDoneScreen.holdDuration, () {
      if (!mounted) return;
      setState(() => _step += 1);
      _scheduleNext();
    });
  }

  /// CTA `첫 일과 만들기` — 자동 전환과 같은 목적지(보호자 홈)로 간다.
  void _goHome() {
    try {
      GoRouter.of(context).go(Routes.guardian);
    } catch (e) {
      debugPrint('라우팅 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    // CTA 하단 여백 — Figma 버튼 하단(741) → 프레임 하단(852) 사이 111.
    // SafeArea가 홈인디케이터만큼 이미 밀어 올리므로 그만큼 빼야
    // Figma와 같은 자리에 놓인다 (ElumScaffold의 ctaBottom과 같은 계산).
    final ctaBottom = ((_frameHeight - space.ctaTop - space.buttonH).h -
            MediaQuery.paddingOf(context).bottom)
        .clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Figma Group 5 — 78×78, 노란 원 + 아이 얼굴 (전 단계 공통)
                    SvgPicture.asset(
                      AppAssets.setupDoneIcon,
                      width: _iconSize,
                      height: _iconSize,
                    ),
                    // 아이콘(y=303~381) → 문구(y=444) 사이 63
                    const SizedBox(height: _iconToText),
                    // 문구만 페이드로 교체한다 — 아이콘은 그대로 두어
                    // 화면 전체가 깜빡이는 느낌을 피한다.
                    AnimatedSwitcher(
                      duration: AppMotion.slow,
                      switchInCurve: AppMotion.entry,
                      switchOutCurve: AppMotion.standard,
                      child: Text(
                        SetupDoneScreen.messages[_step],
                        // 문구가 같은 위치에 교체되므로 key로 변경을 알린다
                        key: ValueKey(_step),
                        textAlign: TextAlign.center,
                        style: context.typo.headline.copyWith(
                          // Figma style_H1DCPM은 24/w800이다. headline(26)과 크기가 다르다.
                          fontSize: _titleSize,
                          height: 1.2,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 마지막 단계에서만 CTA 노출 (Figma 204:1120, x=16 / y=675)
            if (_isLastStep)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  space.buttonMarginH.w,
                  0,
                  space.buttonMarginH.w,
                  ctaBottom,
                ),
                child: ElumButton(
                  label: '첫 일과 만들기',
                  onPressed: _goHome,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _iconSize = 78.0;
  static const _iconToText = 63.0;
  static const _titleSize = 24.0;

  /// Figma 프레임 높이 (393×852 기준)
  static const _frameHeight = 852.0;
}
