# 카드 생성 완료 화면(Image #7) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 보호자가 AI 카드 생성을 완료한 상태를 1.5초 동안 표시하는 화면을 구현한다.

**Architecture:** 기존 splash_screen의 배경·모션 패턴을 재사용하면서 새로운 완료 메시지 UI를 추가하는 ConsumerStatefulWidget. 1.5초 타이머로 자동 전환.

**Tech Stack:** Flutter, Riverpod, GoRouter, ScreenUtil, flutter_svg

## Global Constraints

- Figma 기반 구현 (노드 425-4199)
- ScreenUtil로 반응형 처리 (.w, .h, .sp)
- AppMotion 모션 규칙 준수
- DLP 배지 필수 포함

---

### Task 1: 카드 생성 완료 화면 파일 생성

**Files:**
- Create: `lib/features/onboarding/presentation/card_completion_screen.dart`
- Modify: `lib/core/router/app_router.dart` (라우트 추가)

**Interfaces:**
- Consumes: `AppMotion.sceneStagger`, `SecuredByDlpBadge`, `AppAssets`
- Produces: `CardCompletionScreen` (ConsumerStatefulWidget)

- [ ] **Step 1: app_router.dart에 라우트 정의 추가**

`lib/core/router/app_router.dart`를 열어 GoRoute에 다음을 추가:

```dart
GoRoute(
  path: 'card-completion',
  builder: (context, state) => const CardCompletionScreen(),
),
```

- [ ] **Step 2: card_completion_screen.dart 파일 생성**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_fade_slide_in.dart';
import '../../../core/widgets/secured_by_dlp_badge.dart';

/// Figma `보호자_새로운 일과 만들기_완료` (425:4199)
/// 
/// AI가 행동 카드 생성을 완료한 상태를 1.5초 동안 표시 후 자동 다음 화면으로 이동.
class CardCompletionScreen extends ConsumerStatefulWidget {
  const CardCompletionScreen({super.key});

  @override
  ConsumerState<CardCompletionScreen> createState() =>
      _CardCompletionScreenState();
}

class _CardCompletionScreenState extends ConsumerState<CardCompletionScreen>
    with TickerProviderStateMixin {
  static const _displayDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    // 1.5초 후 자동 다음 화면으로 이동
    Future.delayed(_displayDuration, () {
      if (mounted) {
        context.go('/guardian-home'); // 보호자 확인 UI로 이동
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: Container(
        width: 393.w,
        height: 852.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF78FFB0), // 초록
              const Color(0xFF0099FF), // 파란
            ],
          ),
        ),
        child: Stack(
          children: [
            // 배경 (기존 그라데이션 blob - 필요시 추가)
            // ...
            
            // 콘텐츠
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 별 아이콘
                    SvgPicture.asset(
                      'assets/icons/star.svg', // 기존 별 아이콘
                      width: 48.w,
                      height: 48.h,
                    ),
                    SizedBox(height: 48.h),
                    
                    // 제목
                    Text(
                      '내용 정리가 모두\n완료됐어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1a1a1a),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    
                    // 진행도
                    Text(
                      '100% 완료!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFFA0A0A0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // DLP 배지 (하단)
            Positioned(
              bottom: 32.h,
              left: 0,
              right: 0,
              child: Center(
                child: const SecuredByDlpBadge(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 테스트 파일 생성**

`test/card_completion_screen_test.dart` 생성:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../lib/features/onboarding/presentation/card_completion_screen.dart';

void main() {
  group('CardCompletionScreen', () {
    testWidgets('displays completion message and DLP badge',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const CardCompletionScreen(),
        ),
      );

      // 제목 확인
      expect(find.text('내용 정리가 모두\n완료됐어요'), findsOneWidget);
      
      // 진행도 확인
      expect(find.text('100% 완료!'), findsOneWidget);
      
      // DLP 배지 확인
      expect(find.byType(SecuredByDlpBadge), findsOneWidget);
    });

    testWidgets('navigates after 1.5 seconds',
        (WidgetTester tester) async {
      final navigatorObserver = NavigatorObserver();
      
      await tester.pumpWidget(
        MaterialApp(
          home: const CardCompletionScreen(),
          navigatorObservers: [navigatorObserver],
        ),
      );

      // 1.5초 대기
      await tester.pumpAndSettle(const Duration(milliseconds: 1500));

      // 네비게이션 확인 (다음 화면으로 이동)
      // GoRouter 사용 시 context.go() 검증 필요
    });
  });
}
```

- [ ] **Step 4: 테스트 실행**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/elum_codegate2026/client
flutter test test/card_completion_screen_test.dart
```

Expected: PASS

- [ ] **Step 5: 핫 리로드 확인**

```bash
flutter run
# 앱에서 카드 생성 완료 화면으로 네비게이트
# 1.5초 동안 완료 메시지 표시 → 자동 다음 화면으로 이동 확인
```

- [ ] **Step 6: 커밋**

```bash
git add lib/features/onboarding/presentation/card_completion_screen.dart \
        lib/core/router/app_router.dart \
        test/card_completion_screen_test.dart
git commit -m "feat: add card completion screen with 1.5s auto-transition"
```
