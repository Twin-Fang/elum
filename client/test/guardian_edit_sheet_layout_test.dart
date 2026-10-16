import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_bottom_sheet.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/presentation/guardian_edit_sheet.dart';
import 'package:elum/features/profile/presentation/guardians_screen.dart';
import 'package:elum/features/profile/presentation/widgets/guardian_person_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';

/// 이름 변경 시트 자리: 홈 인디케이터가 34 인 기기(iPhone 16)에서도 시안(1532:6877) 위치
void main() {
  useFigmaViewport();

  // 시트 윗변 · 저장 버튼 윗변 (시안 export 실측, 논리 px)
  const designSheetTop = 407.0;
  const designSaveButtonTop = 730.0;
  // 입력칸 왼쪽 끝에서 글자 시작까지 (시안 글자 x 40 - 칸 x 16)
  const designFieldTextInset = 24.0;

  Future<void> openSheet(WidgetTester tester, {double bottomInset = 34}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true)),
          memberProvider.overrideWith((ref) async => memberWith([kProfileA])),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.only(top: 59, bottom: bottomInset),
              ),
              child: child!,
            ),
            routerConfig: GoRouter(
              initialLocation: '/x',
              routes: [GoRoute(path: '/x', builder: (_, _) => const GuardiansScreen())],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(guardianRenameButtonKey));
    await tester.pumpAndSettle();
  }

  testWidgets('하단 안전영역이 34 여도 시트 윗변과 저장 버튼이 시안 자리에 선다', (tester) async {
    await openSheet(tester);

    expect(tester.getTopLeft(find.byType(ElumSheetSurface)).dy, closeTo(designSheetTop, 1));
    expect(tester.getTopLeft(find.byKey(guardianEditSaveButtonKey)).dy, closeTo(designSaveButtonTop, 1));
  });

  testWidgets('입력칸 글자는 칸 왼쪽에서 시안 여백만큼 떨어져 시작한다', (tester) async {
    await openSheet(tester);

    final fieldLeft = tester.getTopLeft(find.byKey(guardianEditNameFieldKey)).dx;
    final textLeft = tester.getTopLeft(find.byType(EditableText)).dx;
    expect(textLeft - fieldLeft, closeTo(designFieldTextInset, 0.5));
  });
}
