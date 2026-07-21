import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../application/onboarding_notifier.dart';

/// Figma `온보딩_맞춤설정완료`(204:1042) — 온보딩 결과를 저장하는 전환 화면.
///
/// **누를 것이 없다.** CTA도 뒤로가기도 없이 잠깐 보였다가 보호자 홈으로 넘어간다.
/// 저장이 순식간에 끝나도 화면이 깜빡이고 지나가면 안 되므로 최소 시간을 두고 머문다.
class SetupDoneScreen extends ConsumerStatefulWidget {
  const SetupDoneScreen({super.key});

  /// 화면에 머무는 최소 시간.
  ///
  /// 저장은 로컬이라 대개 즉시 끝난다. 그대로 넘기면 화면이 깜빡이기만 하고
  /// 무슨 일이 있었는지 보호자가 읽을 틈이 없다.
  static const holdDuration = Duration(milliseconds: 1600);

  @override
  ConsumerState<SetupDoneScreen> createState() => _SetupDoneScreenState();
}

class _SetupDoneScreenState extends ConsumerState<SetupDoneScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _saveAndContinue();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 저장을 시작하되, 화면 전환은 저장 완료를 기다리지 않는다.
  ///
  /// 저장 실패가 데모를 막으면 안 된다(docs 원칙 6번). notifier가 예외를
  /// 삼키므로 여기서는 시간만 재고 넘어간다.
  void _saveAndContinue() {
    unawaited(ref.read(onboardingProvider.notifier).complete());

    _timer = Timer(SetupDoneScreen.holdDuration, () {
      if (mounted) {
        try {
          GoRouter.of(context).go(Routes.guardian);
        } catch (e) {
          debugPrint('라우팅 실패: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Figma Group 5 — 78×78, 노란 원 + 아이 얼굴
              SvgPicture.asset(
                AppAssets.setupDoneIcon,
                width: _iconSize,
                height: _iconSize,
              ),
              // 아이콘(y=303~381) → 문구(y=444) 사이 63
              const SizedBox(height: _iconToText),
              Text(
                // Figma 문구를 그대로 쓴다. 줄바꿈 위치도 디자인이 정한 대로다.
                '준비물은 눈에 보이는\n체크리스트로 보여드려요',
                textAlign: TextAlign.center,
                style: context.typo.headline.copyWith(
                  // Figma는 24/w800이다. headline(26)과 크기가 다르다.
                  fontSize: _titleSize,
                  height: 1.2,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _iconSize = 78.0;
  static const _iconToText = 63.0;
  static const _titleSize = 24.0;
}
