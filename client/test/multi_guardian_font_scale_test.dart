import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/kept_text.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/domain/guardian_member.dart';
import 'package:elum/features/profile/presentation/guardians_screen.dart';
import 'package:elum/features/profile/presentation/invite_code_screen.dart';
import 'package:elum/features/profile/presentation/guardian_edit_sheet.dart';
import 'package:elum/features/profile/presentation/widgets/guardian_person_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/kept_text_finder.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 시스템 글자를 가장 크게 키운 보호자에게도 새 화면이 깨지지 않는다 (#362 · 디자인 원칙 §7-2 #19).
///
/// 50대 보호자가 흔히 켜 두는 설정이다. 넘침(overflow)은 `flutter_test_config.dart` 가 자동으로
/// 실패시키므로 여기서는 화면을 크게 띄워 보기만 하면 된다. 가장 긴 문구(마지막 보호자 안내·
/// 오류 문구)가 들어간 상태로 본다.
void main() {
  useFigmaViewport();

  late FakeProfileRepository repo;

  setUp(() => repo = FakeProfileRepository());

  Future<void> pump(WidgetTester tester, String path, Widget screen, {double scale = 2.0}) async {
    final router = GoRouter(
      initialLocation: path,
      routes: [GoRoute(path: path, builder: (_, _) => screen)],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true)),
          memberProvider.overrideWith((ref) async => memberWith([kProfileA, kProfileB])),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets('초대 코드 만들기 — 글꼴 $scale', (tester) async {
      await pump(tester, Routes.guardianInvite, const InviteCodeScreen(), scale: scale);
      expect(find.byType(InviteCodeScreen), findsOneWidget);
    });

  }

  /// 마지막 줄에 남은 글 (끊지 말라는 표시 제외)
  String lastLineOf(WidgetTester tester, String wholeText) {
    // 끊지 말라는 표시가 섞인 글이라 원문(KeptText.text)으로 위젯을 찾는다
    final keptText = find.byWidgetPredicate((w) => w is KeptText && w.text.contains(wholeText));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: keptText, matching: find.byType(RichText)),
    );
    final text = paragraph.text.toPlainText();
    // 맨 아래 줄 왼쪽 끝 글자부터 끝까지
    final start = paragraph.getPositionForOffset(Offset(0, paragraph.size.height - 1)).offset;
    return text.substring(start).replaceAll('\u2060', '').trim();
  }

  testWidgets('접근성 최대 글꼴(3.0): 줄은 잘리지 않고 늘어나며 어절 중간에서 꺾이지 않는다', (tester) async {
    repo.guardiansResult = const Attempt.ok([
      Guardian(id: 'g-1', me: true, displayName: '이름이 아주 긴 보호자 엄마입니다'),
      Guardian(id: 'g-2', me: false, displayName: '아빠'),
    ]);
    await pump(tester, Routes.guardianPeople, const GuardiansScreen(), scale: 3.0);

    // 시안 높이 68 은 최소값 — 넘침은 flutter_test_config 가 실패시키므로 줄이 늘어나야 한다
    expect(tester.getSize(find.byType(GuardianPersonRow).first).height, greaterThan(68));
    expect(find.byKey(guardianRenameButtonKey), findsOneWidget);
    // `2` 와 `명`, `초대하` 와 `기` 로 갈라지지 않고 띄어쓰기에서 꺾인다
    expect(lastLineOf(tester, '함께 돌보는 사람'), endsWith('2명'));
    expect(lastLineOf(tester, '다른 보호자 초대하기'), endsWith('초대하기'));
  });

  testWidgets('글꼴 2.0: 이름 변경 시트가 넘치지 않고 스크롤로 저장 버튼이 화면 안에 닿는다', (tester) async {
    await pump(tester, Routes.guardianPeople, const GuardiansScreen());

    await tester.tap(find.byKey(guardianRenameButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(guardianEditSaveButtonKey));
    await tester.pump();
    final rect = tester.getRect(find.byKey(guardianEditSaveButtonKey));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(852));
  });

  testWidgets('나가기 확인 팝업 — 마지막 보호자 문구가 글꼴 2.0 에서도 나가기·취소 버튼을 가리지 않는다', (tester) async {
    repo.guardiansResult = const Attempt.ok([Guardian(id: 'g-1', me: true)]);
    await pump(tester, Routes.guardianPeople, const GuardiansScreen());

    await tester.ensureVisible(findKept('함께 돌보기 그만두기', exact: true));
    await tester.pump();
    await tester.tap(findKept('함께 돌보기 그만두기', exact: true));
    await tester.pumpAndSettle();

    expect(findKept('되돌릴 수 없어요'), findsOneWidget);
    expect(find.text('그만두기'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
  });
}
