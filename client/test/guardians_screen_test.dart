import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/domain/guardian_member.dart';
import 'package:elum/features/profile/presentation/guardian_edit_sheet.dart';
import 'package:elum/features/profile/presentation/guardians_screen.dart';
import 'package:elum/features/profile/presentation/widgets/guardian_person_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/kept_text_finder.dart';
import 'helpers/profile_fixtures.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 함께하는 사람 · 이 이룸이에서 나가기 (#362 · E15·E19·E20·E29).
///
/// **나가기는 되돌릴 수 없다.** 그래서 두 가지를 가장 먼저 고정한다 — 확인하기 전에는 서버에
/// 아무것도 보내지 않는다는 것, 그리고 마지막 보호자면 이룸이까지 사라진다고 **먼저** 말한다는 것.
void main() {
  useFigmaViewport();

  late FakeProfileRepository repo;
  late InMemoryStorage storage;
  var profiles = [kProfileA, kProfileB];

  setUp(() {
    repo = FakeProfileRepository();
    storage = InMemoryStorage(onboardingCompleted: true, pin: '1234');
    profiles = [kProfileA, kProfileB];
  });

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.guardianPeople,
      routes: [
        GoRoute(path: Routes.guardianPeople, builder: (_, _) => const GuardiansScreen()),
        GoRoute(path: Routes.guardianInvite, builder: (_, _) => const Scaffold(body: Text('초대 코드 만들기 화면'))),
        GoRoute(path: Routes.inviteEnter, builder: (_, _) => const Scaffold(body: Text('초대 코드 넣기 화면'))),
        GoRoute(path: Routes.guardian, builder: (_, _) => const Scaffold(body: Text('보호자 홈'))),
        GoRoute(path: Routes.onboardingName, builder: (_, _) => const Scaffold(body: Text('이룸이 등록'))),
      ],
    );
    return ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        localStorageProvider.overrideWithValue(storage),
        memberProvider.overrideWith((ref) async => memberWith(profiles)),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  group('주기 갱신', () {
    int listCalls() => repo.calls.where((c) => c == 'list:p-a').length;


    testWidgets('갱신이 실패해도(오프라인) 받아 둔 목록을 오류 화면으로 바꾸지 않는다', (tester) async {
      await open(tester);

      repo.guardiansResult = const Attempt.failed(AppFailure(fault: NetworkFault.offline));
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      // Riverpod 이 실패를 스스로 다시 시도할 수 있어 정확한 횟수 대신 시도했는지만 본다.
      expect(listCalls(), greaterThanOrEqualTo(2), reason: '실패해도 시도는 했다');
      expect(find.text('엄마'), findsOneWidget);
      expect(find.textContaining('E-NET-OFFLINE'), findsNothing);
    });

  });

  group('목록', () {
    testWidgets('이름을 정하지 않은 내 줄은 보호자로 보이고 구분 칩은 선생님이다', (tester) async {
      repo.guardiansResult = const Attempt.ok([
        Guardian(id: 'g-1', me: true),
        Guardian(id: 'g-2', me: false, displayName: '2반', kind: GuardianKind.caregiver),
      ]);
      await open(tester);

      // 내 줄: 이름 자리 + 구분 칩이 모두 보호자
      expect(find.text('보호자'), findsNWidgets(2));
      expect(find.text('선생님'), findsOneWidget);
    });





    testWidgets('불러오지 못하면 에러 코드와 다시 시도를 보이고 나가기는 막는다', (tester) async {
      repo.guardiansResult = const Attempt.failed(AppFailure(fault: NetworkFault.offline));
      await open(tester);

      expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
      expect(find.textContaining('다시 시도'), findsOneWidget);
      // 몇 명인지 모르면 "마지막 보호자"인지 말할 수 없다 — 누르게 두지 않는다
      await tester.tap(findKept('함께 돌보기 그만두기', exact: true));
      await tester.pumpAndSettle();
      expect(find.text('함께 돌보기를 그만둘까요?'), findsNothing);

      repo.guardiansResult = const Attempt.ok([Guardian(id: 'g-1', me: true)]);
      await tester.tap(find.textContaining('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('나'), findsOneWidget);
    });





    testWidgets('#506 목록을 못 받으면 혼자인지 모르므로 그만두기 설명을 말하지 않는다', (tester) async {
      repo.guardiansResult = const Attempt.failed(AppFailure(fault: NetworkFault.offline));
      await open(tester);

      expect(find.textContaining('그만두면'), findsNothing);
      expect(findKept('내가 만든 일과만'), findsNothing);
    });

  });


  group('나가기', () {
    testWidgets('먼저 무엇이 사라지고 무엇이 남는지 말한다 — 확인 전에는 아무것도 보내지 않는다', (tester) async {
      await open(tester);

      await tester.tap(findKept('함께 돌보기 그만두기', exact: true));
      await tester.pumpAndSettle();

      expect(find.text('함께 돌보기를 그만둘까요?'), findsOneWidget);
      // 이룸이 휴대폰 연결이 끊어지는 것을 일과보다 먼저 말한다.
      expect(findKept('내가 연결한 이룸이 휴대폰이 있다면 연결이 끊어져요'), findsOneWidget);
      expect(findKept('새 연결 암호를 만들어야 다시 쓸 수 있어요'), findsOneWidget);
      expect(findKept('내가 만든 일과는 사라져요'), findsOneWidget);
      expect(findKept('다른 보호자의 일과·별은 그대로예요'), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('leave')), isEmpty);
    });


    testWidgets('마지막 보호자면 이룸이도 사라진다고 확인 창에서 먼저 알린다', (tester) async {
      repo.guardiansResult = const Attempt.ok([Guardian(id: 'g-1', me: true, displayName: '엄마')]);
      await open(tester);

      await tester.tap(findKept('함께 돌보기 그만두기', exact: true));
      await tester.pumpAndSettle();

      expect(findKept('함께하는 보호자가 없어요'), findsOneWidget);
      expect(findKept('이룸이와 만든 일과, 모은 별이 모두 사라져요'), findsOneWidget);
      expect(findKept('다른 보호자의 일과·별은 그대로예요'), findsNothing);
      expect(findKept('이룸이 휴대폰이 있다면 연결이 끊어져요'), findsNothing);
      expect(repo.calls.where((c) => c.startsWith('leave')), isEmpty);
    });


    testWidgets('마지막 이룸이에서 나가면 이룸이 등록으로 보낸다 — 비밀암호는 남는다 (E29·E45)', (tester) async {
      profiles = [kProfileA];
      repo.guardiansResult = const Attempt.ok([Guardian(id: 'g-1', me: true)]);
      await open(tester);

      await tester.tap(findKept('함께 돌보기 그만두기', exact: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('그만두기'));
      await tester.pumpAndSettle();

      expect(find.text('이룸이 등록'), findsOneWidget);
      expect(storage.isOnboardingCompleted, isFalse);
      expect(await storage.verifyPin('1234'), isTrue);
    });

    testWidgets('실패하면 화면에 머물고 서버 문구와 에러 코드를 보인다 — 아무것도 바뀌지 않았다 (E20)', (tester) async {
      repo.leaveFailure = serverFailure(500, ServerErrorCode.internalServerError, '잠시 후 다시 시도해주세요.');
      await open(tester);

      await tester.tap(findKept('함께 돌보기 그만두기', exact: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('그만두기'));
      await tester.pumpAndSettle();

      expect(find.textContaining('나가지 못했어요'), findsOneWidget);
      expect(find.text('INTERNAL_SERVER_ERROR'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.text('엄마'), findsOneWidget);
      expect(find.text('보호자 홈'), findsNothing);
      expect(storage.selectedProfileId, isNot('p-b'));
      expect(storage.isOnboardingCompleted, isTrue);
    });



  });

  group('내 이름 변경', () {
    testWidgets('이름 변경을 누르면 이름을 바꿔 저장한다 — 바뀐 항목만 보낸다', (tester) async {
      await open(tester);

      await tester.tap(find.byKey(guardianRenameButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '아빠');
      await tester.tap(find.byKey(guardianEditSaveButtonKey));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('update:p-a'));
      expect(repo.lastUpdate, {'kind': null, 'displayName': '아빠'});
      // 목록을 다시 받는다
      expect(repo.calls.where((c) => c.startsWith('list')).length, 2);
    });



    Future<void> openSheet(WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.byKey(guardianRenameButtonKey));
      await tester.pumpAndSettle();
    }

    testWidgets('구분 칩만 바꾸면 구분만 보낸다', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byKey(guardianEditKindChipKey(GuardianKind.caregiver)));
      await tester.tap(find.byKey(guardianEditSaveButtonKey));
      await tester.pumpAndSettle();

      expect(repo.lastUpdate, {'kind': GuardianKind.caregiver, 'displayName': null});
    });

    testWidgets('이름도 구분도 그대로 저장하면 서버에 보내지 않는다', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byKey(guardianEditSaveButtonKey));
      await tester.pumpAndSettle();

      expect(repo.calls.where((c) => c.startsWith('update')), isEmpty);
    });

    testWidgets('이름을 비우고 저장하면 빈 문자열을 보내고 내 줄이 보호자로 보인다', (tester) async {
      await openSheet(tester);

      await tester.enterText(find.byKey(guardianEditNameFieldKey), '');
      // 서버가 이름을 지운 뒤의 목록
      repo.guardiansResult = const Attempt.ok([Guardian(id: 'g-1', me: true)]);
      await tester.tap(find.byKey(guardianEditSaveButtonKey));
      await tester.pumpAndSettle();

      expect(repo.lastUpdate, {'kind': null, 'displayName': ''});
      expect(find.text('엄마'), findsNothing);
      // 이름 자리와 구분 칩이 모두 보호자
      expect(find.text('보호자'), findsNWidgets(2));
    });

    testWidgets('저장하지 못하면 이유와 코드를 보인다', (tester) async {
      repo.updateResult = Attempt.failed(serverFailure(400, ServerErrorCode.invalidInputValue, '입력값이 올바르지 않아요.'));
      await open(tester);

      await tester.tap(find.byKey(guardianRenameButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '아빠');
      await tester.tap(find.byKey(guardianEditSaveButtonKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('입력값이 올바르지 않아요.'), findsOneWidget);
      expect(find.text('INVALID_INPUT_VALUE'), findsOneWidget);
    });
  });
}
