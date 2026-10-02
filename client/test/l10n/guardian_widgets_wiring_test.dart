import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/card_photo.dart';
import 'package:elum/features/guardian/data/card_photo_picker.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/features/guardian/presentation/widgets/ai_credit_card.dart';
import 'package:elum/features/guardian/presentation/widgets/ai_credit_summary_view.dart';
import 'package:elum/features/guardian/presentation/widgets/card_edit_sheet.dart';
import 'package:elum/features/guardian/presentation/widgets/card_photo_permission_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/card_review_parts.dart';
import 'package:elum/features/guardian/presentation/widgets/card_review_reorder_list.dart';
import 'package:elum/features/guardian/presentation/widgets/create_routine_button.dart';
import 'package:elum/features/guardian/presentation/widgets/default_card_art.dart';
import 'package:elum/features/guardian/presentation/widgets/recommended_routine_strip.dart';
import 'package:elum/features/guardian/presentation/widgets/reward_chip.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_detail_sheet.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_flow_scaffold.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_summary_tile.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_swipe_actions.dart';
import 'package:elum/features/guardian/presentation/widgets/step_card_viewer.dart';
import 'package:elum/features/guardian/presentation/widgets/today_routine_section.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/credit_fixtures.dart';
import '../helpers/device_viewport.dart';
import '../helpers/fake_dio.dart';
import '../helpers/fake_reward_api.dart';
import '../helpers/svg_finder.dart';
import '../helpers/test_storage.dart';
import '../photo/fake_photo_picker.dart';

/// 모든 문구를 `⟦키⟧` 로 돌려주는 가짜 번역. 보간 인자는 괄호 안에 넣는다.
///
/// 한국어 결과가 옛 문구와 같아야 하는 추출 작업은 기본값(ko)으로는 화면이 ARB 를 읽는지
/// 하드코딩인지 가려지지 않는다. 화면에 표식이 보이면 그 자리가 그 키를 읽는 것이다.
/// 시험마다 새로 만들어 쓰므로 다른 시험의 실행 순서나 전역 상태에 기대지 않는다.
class _KeySpy implements AppLocalizations {
  @override
  String get localeName => 'ko';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final raw = invocation.memberName.toString();
    final name = RegExp(r'"(.*)"').firstMatch(raw)!.group(1)!;
    if (invocation.isGetter) return '⟦$name⟧';
    return '⟦$name(${invocation.positionalArguments.join(',')})⟧';
  }
}

class _SpyDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SpyDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(_KeySpy());

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

/// 표식 번역을 심은 앱에 [body] 를 올린다. 화면 밖 층(`appL10n`)도 같은 번역을 읽는다.
Future<void> pumpSpy(
  WidgetTester tester,
  Widget body, {
  List<Object> overrides = const [],
  ProviderContainer? container,
  bool scaffold = true,
  GoRouter? router,
}) async {
  setAppL10nForTest(_KeySpy());
  // 표식은 실제 문구보다 길어 좁은 자리에서 넘칠 수 있다. 여기서는 어느 키를 읽는지만 본다
  // (실제 한국어 문구의 넘침은 각 화면의 기존 테스트가 지킨다).
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
  const delegates = <LocalizationsDelegate<dynamic>>[
    _SpyDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  final app = ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (context, _) => router != null
        ? MaterialApp.router(
            theme: AppTheme.light,
            locale: const Locale('ko'),
            supportedLocales: const [Locale('ko')],
            localizationsDelegates: delegates,
            routerConfig: router,
          )
        : MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('ko'),
            supportedLocales: const [Locale('ko')],
            localizationsDelegates: delegates,
            home: scaffold ? Scaffold(body: body) : body,
          ),
  );
  await tester.pumpWidget(
    container == null
        ? ProviderScope(
            // 같은 시험에서 다시 띄워도 이전 공급자 상태를 이어받지 않는다
            key: UniqueKey(),
            retry: (count, error) => null,
            overrides: overrides.cast(),
            child: app,
          )
        : UncontrolledProviderScope(
            key: UniqueKey(),
            container: container,
            child: app,
          ),
  );
}

Future<void> settle(WidgetTester tester, {int ms = 400}) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// 의미 트리의 라벨·힌트·값을 한 덩어리로 모은다 (병합된 라벨도 부분 일치로 찾는다).
String semanticsText(WidgetTester tester) {
  final out = StringBuffer();
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    out
      ..writeln(data.label)
      ..writeln(data.hint)
      ..writeln(data.value);
    // 낭독기 사용자의 동작 이름도 함께 모은다
    for (final id in data.customSemanticsActionIds ?? const <int>[]) {
      out.writeln(CustomSemanticsAction.getAction(id)?.label);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out.toString();
}

/// 글자(리치 텍스트 포함)로 보이는 표식.
Finder shown(String key) => find.textContaining('⟦$key', findRichText: true);

/// [markers] 가 모두 글자(리치 텍스트 포함)로 보이고, [labels] 가 모두 낭독 문구로 읽힌다.
void expectMarkers(
  WidgetTester tester,
  List<String> markers, {
  List<String> labels = const [],
}) {
  for (final m in markers) {
    expect(
      find.textContaining(m, findRichText: true),
      findsWidgets,
      reason: '$m 를 읽는 자리가 없다',
    );
  }
  if (labels.isEmpty) return;
  final text = semanticsText(tester);
  for (final l in labels) {
    expect(text, contains(l), reason: '$l 낭독 문구를 읽는 자리가 없다');
  }
}

/// 화면에 그려진 모든 글자. 어절 보호용 보이지 않는 표시(U+2060)는 뺀다.
String drawnText(WidgetTester tester) => [
  for (final r in tester.widgetList<RichText>(find.byType(RichText)))
    r.text.toPlainText(),
].join('\n').replaceAll('\u2060', '');

/// 표식 문자열에서 키 이름만 뽑는다 (`⟦키(인자)⟧` → `키`).
String keyOf(String marker) => RegExp(r'⟦(\w+)').firstMatch(marker)!.group(1)!;

// --- 시험마다 확인하는 표식. 마지막 시험이 이 목록의 합을 ARB 의 새 키와 맞춰 본다. ---
// 목록이 시험의 기대값을 그대로 이끌므로(시험이 이 상수를 읽는다) 목록과 시험이 어긋나지 않는다.

const _partsMarkers = [
  '⟦cardReviewMade(5)⟧',
  '⟦cardReviewMade(12)⟧',
  '⟦cardReviewRewardLead⟧젤리 먹기',
  '⟦cardReviewRewardSet⟧',
  '⟦cardReviewReorderHint⟧',
  '⟦cardReviewToolReorder⟧',
  '⟦cardReviewToolEdit⟧',
  '⟦cardReviewToolAdd⟧',
  '⟦cardReviewReorderTitle⟧',
  '⟦cardReviewEmptyTitle⟧',
  '⟦cardReviewEmptyBody⟧',
];
const _partsLabels = ['⟦cardReviewReorderCancel⟧'];

const _smallMarkers = [
  '⟦routineCreateButton⟧',
  '⟦cardAddPhoto⟧',
  '⟦routineTileRewardLabel⟧',
  '⟦routineTileRerun⟧',
  '⟦rewardInputHint⟧',
];
// 밀기 버튼은 그림만 있어 이름이 낭독 문구로만 읽힌다
const _smallLabels = [
  '⟦cardAddPhoto⟧',
  '⟦routineSwipeDelete⟧',
  '⟦routineSwipeEdit⟧',
];

const _actionCardLabels = ['⟦cardSpeak⟧', '⟦cardDeleteLabel⟧'];
const _actionCardStopLabels = ['⟦cardSpeakStop⟧'];

const _reorderListLabels = ['⟦cardMoveForward⟧', '⟦cardMoveBackward⟧'];

const _suggestMarkers = ['⟦routineSuggestLoadFailed⟧'];

// 카메라가 막히면 아래 버튼은 갤러리로 바꾸는 길이다
const _permissionCameraMarkers = [
  '⟦cardPhotoPermissionGallery⟧',
  '⟦cardPhotoPermissionOpenSettings⟧',
  '⟦cardPhotoPermissionCameraTitle⟧',
  '⟦cardPhotoPermissionCameraBody⟧',
];
// 사진 접근이 막히면 아래 버튼은 사진 찍기로 바꾸는 길이다
const _permissionGalleryMarkers = [
  '⟦cardPhotoPermissionTake⟧',
  '⟦cardPhotoPermissionGalleryTitle⟧',
  '⟦cardPhotoPermissionGalleryBody⟧',
];
const _permissionFailedMarkers = [
  '⟦cardPhotoSettingsFailedTitle⟧',
  '⟦cardPhotoSettingsFailedFallback⟧',
];

const _sourceSheetMarkers = [
  '⟦cardPhotoSourceTake⟧',
  '⟦cardPhotoSourceGallery⟧',
  '⟦commonClose⟧',
  '⟦cardPhotoSourcePrivacy⟧',
];

const _editSheetMarkers = [
  '⟦cardEditTitle⟧',
  '⟦cardEditFieldTitle⟧',
  '⟦cardEditTitleHint⟧',
  '⟦cardEditFieldDescription⟧',
  '⟦cardEditDescriptionHint⟧',
  '⟦cardEditDoneAction⟧',
  '⟦cardPhotoChange⟧',
];
const _addSheetMarkers = ['⟦cardEditAddTitle⟧', '⟦cardEditAddAction⟧'];

const _photoUploadingMarkers = ['⟦cardPhotoUploading⟧'];
const _photoFailedRetryMarkers = [
  '⟦cardPhotoUploadFailed⟧',
  '⟦cardPhotoRetry⟧',
];
const _photoFailedDismissMarkers = ['⟦commonConfirm⟧'];
// 서버 문구가 없을 때 기본 안내는 앱 언어로 푼다 (서버 문구가 있으면 그것이 이긴다)
const _photoUploadFailedDialogMarkers = ['⟦cardPhotoUploadFailedDialog('];

const _creditMarkers = [
  '⟦creditCardTitle⟧',
  '⟦creditAmountRest(100)⟧',
  '⟦aiCreditResetLine(',
];
// 낭독용 숫자 줄은 글자가 아니라 낭독 문구로만 읽힌다
const _creditLabels = ['⟦creditInfoLabel⟧', '⟦creditAmountLeft(72,100)⟧'];
const _creditGeneratingMarkers = ['⟦creditGenerating⟧'];
const _creditExhaustedMarkers = [
  '⟦creditExhausted⟧',
  '⟦creditExhaustedStillOk⟧',
];
const _creditExhaustedLabels = ['⟦creditAmountLeft(0,100)⟧'];
const _creditLoadingLabels = ['⟦creditCardLoading⟧'];
const _creditErrorMarkers = [
  '⟦creditCardTitle⟧',
  '⟦creditCardLoadFailed⟧',
  '⟦creditCardRetry⟧',
];
const _creditInfoMarkers = [
  '⟦creditCostTitle⟧',
  '⟦creditCostLine(1,2)⟧',
  '⟦creditCostKeepGoing⟧',
  '⟦creditWeeklyRefill⟧',
];

const _viewerLabels = ['⟦cardViewerClose⟧'];
const _viewerSoundFailedMarkers = [
  '⟦cardViewerSoundFailedTitle⟧',
  '⟦cardViewerSoundFailedFallback⟧',
];

const _detailMarkers = ['⟦routineDetailEdit⟧'];
const _detailLabels = ['⟦routineDetailOpenHint⟧'];
const _detailPastMarkers = ['⟦routineDetailRerun⟧', '⟦routineDetailNoReward⟧'];
const _detailReorderFailedMarkers = [
  '⟦routineDetailReorderFailedTitle⟧',
  '⟦routineDetailReorderFailedFallback⟧',
];

const _flowLabels = ['⟦routineFlowHomeLabel⟧', '⟦routineFlowDraftLabel⟧'];
const _flowDraftMarkers = ['⟦routineFlowDraftLabel⟧'];
const _leaveButtons = ['⟦routineFlowLeaveStay⟧', '⟦routineFlowLeaveConfirm⟧'];
const _leaveDiscard = [
  '⟦routineLeaveDiscardTitle⟧',
  '⟦routineLeaveDiscardMessage⟧',
];
const _leaveDraftWhenReady = [
  '⟦routineLeaveDraftWhenReadyTitle⟧',
  '⟦routineLeaveDraftWhenReadyMessage⟧',
];
const _leaveDraft = ['⟦routineLeaveDraftTitle⟧', '⟦routineLeaveDraftMessage⟧'];
const _leaveEdit = ['⟦routineLeaveEditTitle⟧', '⟦routineLeaveEditMessage⟧'];

const _todayEmptyMarkers = [
  '⟦todayRoutineEmptyTitle⟧',
  '⟦todayRoutineEmptyHint⟧',
];
const _todayLoadFailedMarkers = ['⟦todayRoutineLoadFailedFallback⟧'];
const _todayDeleteConfirmMarkers = [
  '⟦todayRoutineDeleteConfirmTitle⟧',
  '⟦commonCancel⟧',
  '⟦todayRoutineDeleteAction⟧',
];
const _todayDeleteFailedMarkers = [
  '⟦todayRoutineDeleteFailedTitle⟧',
  '⟦todayRoutineDeleteFailedFallback⟧',
];
const _todayReorderFailedMarkers = [
  '⟦todayRoutineReorderFailedTitle⟧',
  '⟦todayRoutineReorderFailedFallback⟧',
];
const _pastEmptyMarkers = ['⟦todayRoutinePastEmpty⟧'];
const _pastLoadFailedMarkers = ['⟦todayRoutinePastLoadFailedFallback⟧'];
const _rerunFailedMarkers = [
  '⟦todayRoutineRerunFailedTitle⟧',
  '⟦todayRoutineRerunFailedFallback⟧',
];
const _rerunCopiedMarkers = ['⟦todayRoutineCopied(어제 한 일)⟧'];

const _coachMarkers = [
  '⟦homeCoachCreate⟧',
  '⟦homeCoachSwipe⟧',
  '⟦homeCoachSwitch⟧',
];

/// 이 작업이 새로 만든(또는 쓰는) 키 가운데 위 시험들이 화면에서 확인하는 키 전부.
const _everyChecked = <List<String>>[
  _partsMarkers,
  _partsLabels,
  _smallMarkers,
  _smallLabels,
  _actionCardLabels,
  _actionCardStopLabels,
  _reorderListLabels,
  _suggestMarkers,
  _permissionCameraMarkers,
  _permissionGalleryMarkers,
  _permissionFailedMarkers,
  _sourceSheetMarkers,
  _editSheetMarkers,
  _addSheetMarkers,
  _photoUploadingMarkers,
  _photoFailedRetryMarkers,
  _photoFailedDismissMarkers,
  _photoUploadFailedDialogMarkers,
  _creditMarkers,
  _creditLabels,
  _creditGeneratingMarkers,
  _creditExhaustedMarkers,
  _creditExhaustedLabels,
  _creditLoadingLabels,
  _creditErrorMarkers,
  _creditInfoMarkers,
  _viewerLabels,
  _viewerSoundFailedMarkers,
  _detailMarkers,
  _detailLabels,
  _detailPastMarkers,
  _detailReorderFailedMarkers,
  _flowLabels,
  _flowDraftMarkers,
  _leaveButtons,
  _leaveDiscard,
  _leaveDraftWhenReady,
  _leaveDraft,
  _leaveEdit,
  _todayEmptyMarkers,
  _todayLoadFailedMarkers,
  _todayDeleteConfirmMarkers,
  _todayDeleteFailedMarkers,
  _todayReorderFailedMarkers,
  _pastEmptyMarkers,
  _pastLoadFailedMarkers,
  _rerunFailedMarkers,
  _rerunCopiedMarkers,
  _coachMarkers,
];

const _routine = Routine(
  id: 'r1',
  title: '학교에 가요',
  status: 'CONFIRMED',
  rewardText: '젤리',
  steps: [
    ActionCard(id: 'c1', title: '옷을 입어요', description: '옷 설명', stepOrder: 1),
    ActionCard(id: 'c2', title: '가방을 싸요', description: '가방 설명', stepOrder: 2),
    ActionCard(id: 'c3', title: '신발을 신어요', description: '신발 설명', stepOrder: 3),
  ],
);

void main() {
  useFigmaViewport();

  // 표식 번역을 전역 통로에 남기지 않는다
  tearDown(setAppL10nForTest);

  group('카드 검토 부품', () {
    testWidgets('머리·보상 줄·안내·도구 버튼·상단 바·빈 상태가 각자의 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSpy(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              const CardReviewHead(count: 5),
              const CardReviewHead(count: 12),
              CardReviewRewardRow(reward: '젤리 먹기', onTap: () {}),
              CardReviewRewardRow(reward: null, onTap: () {}),
              const CardReviewReorderHint(),
              CardReviewToolRow(
                reorderMode: false,
                onReorder: () {},
                onFinishReorder: () {},
                onEdit: () {},
                onAdd: () {},
              ),
              CardReviewReorderTopBar(onClose: () {}),
              const SizedBox(height: 200, child: CardReviewEmpty()),
            ],
          ),
        ),
      );
      await settle(tester);

      expectMarkers(tester, _partsMarkers, labels: _partsLabels);
      // 개수는 인자로 넘어간다 (한 자리·두 자리)
      expect(find.text('⟦cardReviewMade(5)⟧'), findsOneWidget);
      expect(find.text('⟦cardReviewMade(12)⟧'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('순서 바꾸기 낭독 동작이 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSpy(
        tester,
        SizedBox(
          height: 500,
          child: CardReviewReorderList(
            cards: _routine.steps,
            routineId: 'r1',
            cardWidth: 333,
            cardGap: 13,
            onReorder: (_, _) {},
          ),
        ),
      );
      await settle(tester);

      expectMarkers(tester, const [], labels: _reorderListLabels);
      handle.dispose();
    });
  });

  group('작은 부품', () {
    testWidgets('새 일과 버튼·사진 자리·밀기 버튼·일과 줄·보상 입력칸이 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpSpy(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              CreateRoutineButton(onTap: () {}),
              DefaultCardPhotoSlot(onAddPhoto: () {}),
              SizedBox(
                width: 361,
                height: 68,
                child: RoutineSwipeActions(
                  isOpen: true,
                  onOpenChanged: (_) {},
                  onDelete: () {},
                  onEdit: () {},
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
              RoutineSummaryTile(
                routine: _routine,
                progress: 0.5,
                onRerun: () {},
              ),
              RewardInputField(controller: controller, onChanged: (_) {}),
            ],
          ),
        ),
      );
      await settle(tester);

      expectMarkers(tester, _smallMarkers, labels: _smallLabels);
      handle.dispose();
    });

    testWidgets('사진 자리는 누를 수 없을 때도 글자가 같은 키를 읽는다', (tester) async {
      await pumpSpy(tester, const DefaultCardPhotoSlot());
      await settle(tester);
      expect(find.text('⟦cardAddPhoto⟧'), findsOneWidget);
    });

    testWidgets('밀기 버튼은 부른 쪽이 준 삭제 이름이 기본 이름을 이긴다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSpy(
        tester,
        SizedBox(
          width: 361,
          height: 68,
          child: RoutineSwipeActions(
            isOpen: true,
            onOpenChanged: (_) {},
            onDelete: () {},
            deleteLabel: '임시저장 삭제',
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      );
      await settle(tester);
      final labels = semanticsText(tester);
      expect(labels, contains('임시저장 삭제'));
      expect(labels, isNot(contains('⟦routineSwipeDelete⟧')));
      handle.dispose();
    });

    testWidgets('카드의 소리·지우기 버튼 이름이 키를 읽고, 읽는 중에는 멈추기 키로 바뀐다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSpy(
        tester,
        ActionCardView(
          card: _routine.steps.first,
          index: 0,
          onSpeak: () {},
          onDelete: () {},
        ),
      );
      await settle(tester);
      expectMarkers(tester, const [], labels: _actionCardLabels);
      expect(semanticsText(tester), isNot(contains('⟦cardSpeakStop⟧')));

      await pumpSpy(
        tester,
        ActionCardView(
          card: _routine.steps.first,
          index: 0,
          onSpeak: () {},
          isSpeaking: true,
        ),
      );
      await settle(tester);
      expectMarkers(tester, const [], labels: _actionCardStopLabels);
      handle.dispose();
    });
  });

  group('추천 목록', () {
    testWidgets('불러오지 못하면 대체 문구 키를 읽고, 서버 문구가 있으면 서버 문구가 이긴다', (tester) async {
      await pumpSpy(
        tester,
        RecommendedRoutineStrip(onTap: (_) {}),
        overrides: [
          routineSuggestionsProvider.overrideWith(
            (ref) async => throw const AppFailure(fault: NetworkFault.app),
          ),
        ],
      );
      await settle(tester);
      expectMarkers(tester, _suggestMarkers);
      expect(find.textContaining('(E-SUGGEST)'), findsOneWidget);

      await pumpSpy(
        tester,
        RecommendedRoutineStrip(onTap: (_) {}),
        overrides: [
          routineSuggestionsProvider.overrideWith(
            (ref) async => throw const AppFailure(
              fault: NetworkFault.none,
              server: ServerError(
                code: ServerErrorCode.unknown,
                statusCode: 500,
                message: '서버가 준 이유',
              ),
            ),
          ),
        ],
      );
      await settle(tester);
      expect(find.textContaining('서버가 준 이유'), findsOneWidget);
      expect(find.textContaining('⟦routineSuggestLoadFailed⟧'), findsNothing);
    });
  });

  group('사진 권한 안내', () {
    Future<void> pumpPermission(
      WidgetTester tester,
      PhotoSource denied,
      _Settings settings,
    ) async {
      await pumpSpy(
        tester,
        CardPhotoPermissionScreen(denied: denied),
        scaffold: false,
        overrides: [photoSettingsProvider.overrideWithValue(settings)],
      );
      await settle(tester);
    }

    testWidgets('카메라가 막히면 카메라 쪽 제목·설명·버튼이 각자의 키를 읽는다', (tester) async {
      await pumpPermission(
        tester,
        PhotoSource.camera,
        _Settings(available: true, opens: false),
      );
      expectMarkers(tester, _permissionCameraMarkers);
      // 갤러리 쪽 문구는 읽지 않는다
      expect(shown('cardPhotoPermissionGalleryTitle'), findsNothing);
      expect(shown('cardPhotoPermissionTake'), findsNothing);
    });

    testWidgets('사진 접근이 막히면 갤러리 쪽 제목·설명·버튼이 각자의 키를 읽는다', (tester) async {
      await pumpPermission(
        tester,
        PhotoSource.gallery,
        _Settings(available: true, opens: false),
      );
      expectMarkers(tester, _permissionGalleryMarkers);
      expect(shown('cardPhotoPermissionCameraTitle'), findsNothing);
      expect(shown('cardPhotoPermissionGallery⟧'), findsNothing);
    });

    testWidgets('설정을 못 열면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpPermission(
        tester,
        PhotoSource.camera,
        _Settings(available: true, opens: false),
      );
      await tester.tap(find.text('⟦cardPhotoPermissionOpenSettings⟧'));
      await settle(tester);
      expectMarkers(tester, _permissionFailedMarkers);
    });
  });

  group('카드 수정 시트와 사진 올리기', () {
    const put = 'PUT /api/routines/r1/steps/c1/image';
    const photoRoutine = Routine(
      id: 'r1',
      status: 'PENDING_REVIEW',
      steps: [
        ActionCard(
          id: 'c1',
          title: '옷을 입어요',
          description: '옷을 입어요',
          stepOrder: 1,
          imagePath: 'k/old.jpg',
        ),
      ],
    );

    ProviderContainer makeContainer(
      Map<String, Object?> routes, {
      FakePhotoPicker? picker,
      Duration delay = Duration.zero,
    }) {
      final container = ProviderContainer(
        overrides: [
          fakeDioOverride(routes, delay: delay),
          testStorageOverride(onboardingCompleted: true),
          cardPhotoPickerProvider.overrideWithValue(
            picker ?? FakePhotoPicker([]),
          ),
          photoSettingsProvider.overrideWithValue(_Settings()),
          speechServiceProvider.overrideWithValue(_Speech(ok: true)),
        ],
      );
      addTearDown(container.dispose);
      container.read(routineFlowProvider.notifier).resumeDraft(photoRoutine);
      return container;
    }

    /// 시트를 여는 버튼이 있는 화면. 입력칸이 비어 있어야 안내 글이 보인다.
    Widget opener({bool add = false}) => Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => add
              ? CardEditSheet.showAdd(context, onSubmit: (_, _) async => true)
              : CardEditSheet.show(
                  context,
                  title: '',
                  description: '',
                  photo: CardPhotoTarget.of(routineId: 'r1', stepId: 'c1'),
                ),
          child: const Text('열기'),
        ),
      ),
    );

    Future<void> pumpOpener(
      WidgetTester tester,
      ProviderContainer container, {
      bool add = false,
    }) async {
      await pumpSpy(tester, opener(add: add), container: container);
      await tester.tap(find.text('열기'));
      await settle(tester);
    }

    testWidgets('수정 시트의 제목·입력칸 이름·안내·완료·사진 칩이 각자의 키를 읽는다', (tester) async {
      await pumpOpener(tester, makeContainer({}));
      expectMarkers(tester, _editSheetMarkers);
      expect(shown('cardEditAddTitle'), findsNothing);
      expect(shown('cardEditAddAction'), findsNothing);
    });

    testWidgets('추가 시트의 제목·버튼이 수정 시트와 다른 키를 읽는다', (tester) async {
      await pumpOpener(tester, makeContainer({}), add: true);
      expectMarkers(tester, _addSheetMarkers);
      expect(shown('cardEditTitle⟧'), findsNothing);
      expect(shown('cardEditDoneAction'), findsNothing);
    });

    testWidgets('사진 고르기 시트가 각자의 키를 읽는다', (tester) async {
      await pumpOpener(tester, makeContainer({}));
      await tester.tap(find.text('⟦cardPhotoChange⟧'));
      await settle(tester);
      expectMarkers(tester, _sourceSheetMarkers);
    });

    Future<void> startUpload(WidgetTester tester) async {
      await tester.tap(find.text('⟦cardPhotoChange⟧'));
      await settle(tester);
      await tester.tap(find.text('⟦cardPhotoSourceTake⟧'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('올리는 중에는 올리는 중 키를, 실패하면 실패 제목·다시 하기 키를 읽는다', (tester) async {
      final container = makeContainer(
        {
          put: const FakeHttpError(
            500,
            errorCode: 'ROUTINE_STEP_IMAGE_SAVE_FAILED',
          ),
        },
        picker: FakePhotoPicker([PhotoPicked(fakeJpeg())]),
        delay: const Duration(seconds: 2),
      );
      await pumpOpener(tester, container);
      await startUpload(tester);
      expectMarkers(tester, _photoUploadingMarkers);

      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expectMarkers(tester, _photoFailedRetryMarkers);
      expect(shown('cardPhotoUploading'), findsNothing);
      // 서버 문구가 없을 때의 안내는 앱 언어 문구(기본)다
      expect(shown('commonRetryLater'), findsWidgets);
    });

    testWidgets('다시 해도 같은 실패는 다시 하기 대신 확인 키를 읽는다', (tester) async {
      final container = makeContainer({
        put: const FakeHttpError(404, errorCode: 'ROUTINE_NOT_FOUND'),
      }, picker: FakePhotoPicker([PhotoPicked(fakeJpeg())]));
      await pumpOpener(tester, container);
      await startUpload(tester);
      await settle(tester);
      expectMarkers(tester, _photoFailedDismissMarkers);
      expect(shown('cardPhotoRetry'), findsNothing);
    });

    testWidgets('사진을 못 고르면 사진 쪽 실패 문구를 앱 언어로 읽는다', (tester) async {
      final container = makeContainer(
        {},
        picker: FakePhotoPicker([const PhotoPickFailed(PhotoFailure.size)]),
      );
      await pumpOpener(tester, container);
      await startUpload(tester);
      await settle(tester);
      expectMarkers(tester, const [
        '⟦cardPhotoUploadFailed⟧',
        '⟦cardPhotoTooLarge⟧',
      ]);
    });

    testWidgets('올리는 도중 시트가 닫히면 팝업 제목이 서버 문구를 담는다', (tester) async {
      final container = makeContainer(
        {
          put: const FakeHttpError(
            500,
            errorCode: 'ROUTINE_STEP_IMAGE_SAVE_FAILED',
            errorMessage: '서버가 준 사유',
          ),
        },
        picker: FakePhotoPicker([PhotoPicked(fakeJpeg())]),
        delay: const Duration(seconds: 2),
      );
      await pumpOpener(tester, container);
      await startUpload(tester);
      // 시트 위쪽 어두운 배경을 눌러 닫는다
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);

      expectMarkers(tester, _photoUploadFailedDialogMarkers);
      // 서버 문구가 앱 기본 문구를 이긴다 (서버 문구 우선 규칙은 그대로)
      expect(
        find.text('⟦cardPhotoUploadFailedDialog(서버가 준 사유)⟧'),
        findsOneWidget,
      );
      expect(find.text('⟦commonConfirm⟧'), findsOneWidget);
    });
  });

  group('AI 크레딧 카드', () {
    CreditSummary summary({
      int available = 72,
      int routineTextCost = 1,
      int cardImageCost = 1,
      List<Object?> inProgress = const [],
    }) => CreditSummary.fromJson(
      creditJson(
        available: available,
        routineTextCost: routineTextCost,
        cardImageCost: cardImageCost,
        inProgress: inProgress,
      ),
    );

    Future<void> pumpCard(
      WidgetTester tester,
      Future<CreditSummary> Function() load,
    ) async {
      await pumpSpy(
        tester,
        const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: AiCreditCard(),
        ),
        overrides: [creditSummaryProvider.overrideWith((ref) => load())],
      );
      await settle(tester);
    }

    testWidgets('정상 — 제목·남은 양·초기화 줄이 각자의 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, () async => summary());
      // 큰 숫자 뒤 작은 글자와 낭독용 숫자 줄은 값을 인자로 넘겨 읽는다
      expectMarkers(tester, _creditMarkers, labels: _creditLabels);
      expect(shown('creditExhausted'), findsNothing);
      handle.dispose();
    });

    testWidgets('값이 달라지면 인자도 달라진다 — 남은 수·주간 지급량', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, () async => summary(available: 5));
      expect(semanticsText(tester), contains('⟦creditAmountLeft(5,100)⟧'));
      expectMarkers(tester, const ['⟦creditAmountRest(100)⟧']);
      handle.dispose();
    });

    testWidgets('다 쓰면 다 썼다·계속 할 수 있다 줄이 각자의 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, () async => summary(available: 0));
      expectMarkers(
        tester,
        _creditExhaustedMarkers,
        labels: _creditExhaustedLabels,
      );
      handle.dispose();
    });

    testWidgets('일과를 만드는 중이면 만드는 중 키를 읽는다', (tester) async {
      await pumpCard(
        tester,
        () async => summary(
          inProgress: [
            {
              'jobId': 'j1',
              'kind': 'ROUTINE_CREATE',
              'startedAt': '2026-09-24T10:00:00',
            },
          ],
        ),
      );
      expectMarkers(tester, _creditGeneratingMarkers);
    });

    testWidgets('불러오는 동안 낭독 문구가 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      final never = Completer<CreditSummary>();
      await pumpCard(tester, () => never.future);
      expect(semanticsText(tester), contains(_creditLoadingLabels.single));
      handle.dispose();
    });

    testWidgets('불러오지 못하면 실패 제목·다시 하기가 키를 읽는다', (tester) async {
      await pumpCard(
        tester,
        () async => throw const AppFailure(fault: NetworkFault.app),
      );
      expectMarkers(tester, _creditErrorMarkers);
    });

    testWidgets('안내 버튼을 누르면 서버 단가를 인자로 넘긴 문장을 읽는다', (tester) async {
      await pumpCard(
        tester,
        () async => summary(routineTextCost: 1, cardImageCost: 2),
      );
      await tester.tap(find.byKey(AiCreditCard.infoKey));
      await settle(tester);
      // 안내 팝업은 어절을 끊지 않으려 보이지 않는 표시를 끼운다 — 뺀 글자로 본다
      final drawn = drawnText(tester);
      for (final m in _creditInfoMarkers) {
        expect(drawn, contains(m), reason: '$m 를 읽는 자리가 없다');
      }
    });

    testWidgets('단가가 바뀌면 안내 문장의 인자도 따라간다', (tester) async {
      await pumpCard(
        tester,
        () async => summary(routineTextCost: 3, cardImageCost: 12),
      );
      await tester.tap(find.byKey(AiCreditCard.infoKey));
      await settle(tester);
      expect(drawnText(tester), contains('⟦creditCostLine(3,12)⟧'));
      // 정적 title·message 도 같은 키를 읽는다 (API 는 그대로)
      expect(CreditInfoButton.title, '⟦creditCostTitle⟧');
      expect(
        CreditInfoButton.message(summary(routineTextCost: 1, cardImageCost: 2)),
        '⟦creditCostLine(1,2)⟧\n⟦creditCostKeepGoing⟧\n⟦creditWeeklyRefill⟧',
      );
    });
  });

  group('카드 크게 보기', () {
    testWidgets('배경 막·닫기·소리 실패가 각자의 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSpy(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => StepCardViewer.show(
              context,
              cards: _routine.steps,
              initialIndex: 0,
              routineId: 'r1',
            ),
            child: const Text('열기'),
          ),
        ),
        overrides: [
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true),
          speechServiceProvider.overrideWithValue(_Speech(ok: false)),
        ],
      );
      await tester.tap(find.text('열기'));
      await settle(tester);

      expectMarkers(tester, const [], labels: _viewerLabels);
      // 배경 막 이름은 글자가 아니라 막 위젯의 낭독 이름이다
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ModalBarrier &&
              w.semanticsLabel == '⟦cardViewerBarrierLabel⟧',
        ),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('⟦cardSpeak⟧').first);
      await settle(tester);
      expectMarkers(tester, _viewerSoundFailedMarkers);
      handle.dispose();
    });
  });

  group('일과 상세 시트', () {
    Future<void> pumpSheet(
      WidgetTester tester,
      Routine routine, {
      bool isPast = false,
      bool reorderFails = false,
    }) async {
      await pumpSpy(
        tester,
        RoutineDetailSheet(routine: routine, isPast: isPast),
        overrides: [
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(
            _Repo(reorderStepsFails: reorderFails),
          ),
          speechServiceProvider.overrideWithValue(_Speech(ok: true)),
        ],
      );
      await tester.pump();
    }

    testWidgets('오늘 일과는 편집하기 키, 카드 줄은 힌트 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSheet(tester, _routine);
      expectMarkers(tester, _detailMarkers, labels: _detailLabels);
      expect(shown('routineDetailRerun'), findsNothing);
      handle.dispose();
    });

    testWidgets('지난 일과는 다시하기 키, 보상이 없으면 보상 없음 키를 읽는다', (tester) async {
      await pumpSheet(tester, _routine.copyWith(rewardText: ''), isPast: true);
      expectMarkers(tester, _detailPastMarkers);
      expect(shown('routineDetailEdit'), findsNothing);
    });

    testWidgets('보상이 있으면 보상 글을 그대로 보인다', (tester) async {
      await pumpSheet(tester, _routine);
      expect(find.text('젤리'), findsOneWidget);
      expect(shown('routineDetailNoReward'), findsNothing);
    });

    testWidgets('순서 저장이 실패하면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpSheet(tester, _routine, reorderFails: true);
      final gesture = await tester.startGesture(
        tester.getCenter(svgWithAsset(AppAssets.sheetReorderHandle).first),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, 160));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expectMarkers(tester, _detailReorderFailedMarkers);
    });
  });

  group('일과 만들기 흐름 뼈대', () {
    Future<void> pumpFlow(WidgetTester tester, RoutineLeave kind) async {
      await pumpSpy(
        tester,
        RoutineFlowScaffold(
          leave: kind,
          showDraftAction: true,
          child: const SizedBox.shrink(),
        ),
        scaffold: false,
        overrides: [
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true),
        ],
      );
      await settle(tester);
    }

    testWidgets('위쪽 집·임시저장 버튼이 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFlow(tester, RoutineLeave.discard);
      expectMarkers(tester, _flowDraftMarkers, labels: _flowLabels);
      handle.dispose();
    });

    for (final (kind, markers) in [
      (RoutineLeave.discard, _leaveDiscard),
      (RoutineLeave.draftWhenReady, _leaveDraftWhenReady),
      (RoutineLeave.draft, _leaveDraft),
      (RoutineLeave.edit, _leaveEdit),
    ]) {
      testWidgets('나가기 팝업 ${kind.name} 의 제목·설명·버튼이 각자의 키를 읽는다', (tester) async {
        await pumpFlow(tester, kind);
        await tester.tap(find.text('⟦routineFlowDraftLabel⟧'));
        await settle(tester);
        expectMarkers(tester, markers);
        expectMarkers(tester, _leaveButtons);
        // 같은 문구라도 다른 종류의 팝업은 자기 키만 읽는다
        for (final other in [
          _leaveDiscard,
          _leaveDraftWhenReady,
          _leaveDraft,
          _leaveEdit,
        ]) {
          if (identical(other, markers)) continue;
          for (final m in other) {
            if (markers.contains(m)) continue;
            expect(find.textContaining(m, findRichText: true), findsNothing);
          }
        }
      });
    }
  });

  group('오늘·지난 일과 구역', () {
    Routine routine(String id, String title) => Routine(
      id: id,
      title: title,
      status: 'CONFIRMED',
      steps: [ActionCard(id: '$id-1', stepOrder: 1, description: '첫 단계')],
    );

    Future<void> pumpSection(
      WidgetTester tester,
      Widget section,
      _Repo repo,
    ) async {
      await pumpSpy(
        tester,
        SingleChildScrollView(child: section),
        overrides: [
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await settle(tester);
    }

    testWidgets('오늘 일과가 없으면 빈 상태 두 줄이 각자의 키를 읽는다', (tester) async {
      await pumpSection(tester, const TodayRoutineSection(), _Repo());
      expectMarkers(tester, _todayEmptyMarkers);
    });

    testWidgets('오늘 일과를 못 받으면 서버 문구가 없을 때 기본 안내 키를 읽는다', (tester) async {
      await pumpSection(
        tester,
        const TodayRoutineSection(),
        _Repo(todayError: const AppFailure(fault: NetworkFault.app)),
      );
      expectMarkers(tester, _todayLoadFailedMarkers);
    });

    testWidgets('일과를 지우려 하면 확인 팝업이, 서버가 거절하면 실패 팝업이 각자의 키를 읽는다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSection(
        tester,
        const TodayRoutineSection(),
        _Repo(
          today: [routine('a', '손 씻기')],
          deleteFailure: const AppFailure(fault: NetworkFault.app),
        ),
      );
      await tester.drag(find.text('손 씻기'), const Offset(-200, 0));
      await settle(tester);
      // 밀어 연 줄의 삭제 버튼 — 부른 쪽이 이름을 주지 않아 기본 키를 읽는다
      await tester.tap(find.bySemanticsLabel('⟦routineSwipeDelete⟧'));
      await settle(tester);
      expectMarkers(tester, _todayDeleteConfirmMarkers);

      await tester.tap(find.text('⟦todayRoutineDeleteAction⟧'));
      await settle(tester);
      expectMarkers(tester, _todayDeleteFailedMarkers);
      handle.dispose();
    });

    testWidgets('순서 저장이 실패하면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpSection(
        tester,
        const TodayRoutineSection(),
        _Repo(
          today: [routine('a', '손 씻기'), routine('b', '양치')],
          reorderFailure: const AppFailure(fault: NetworkFault.app),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('손 씻기')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      // 목록이 끌림을 알아채도록 조금씩 옮긴다
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 25));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expectMarkers(tester, _todayReorderFailedMarkers);
    });

    testWidgets('지난 일과가 없으면 빈 줄 키를 읽는다', (tester) async {
      await pumpSection(tester, const PastRoutineSection(), _Repo());
      expectMarkers(tester, _pastEmptyMarkers);
    });

    testWidgets('지난 일과를 못 받으면 서버 문구가 없을 때 기본 안내 키를 읽는다', (tester) async {
      await pumpSection(
        tester,
        const PastRoutineSection(),
        _Repo(pastError: const AppFailure(fault: NetworkFault.app)),
      );
      expectMarkers(tester, _pastLoadFailedMarkers);
    });

    /// 지난 일과를 눌러 시트를 열고 다시하기를 누른다.
    Future<void> rerun(WidgetTester tester, _Repo repo) async {
      await pumpSection(tester, const PastRoutineSection(), repo);
      await tester.tap(find.text('어제 한 일'));
      await settle(tester);
      await tester.tap(find.text('⟦routineDetailRerun⟧'));
      await settle(tester);
    }

    testWidgets('다시 만들기가 실패하면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await rerun(
        tester,
        _Repo(
          past: [routine('p1', '어제 한 일')],
          duplicateFailure: const AppFailure(fault: NetworkFault.app),
        ),
      );
      expectMarkers(tester, _rerunFailedMarkers);
    });

    for (final title in ['어제 한 일', '양치']) {
      testWidgets('다시 만들면 일과 제목($title)을 인자로 넘겨 알린다', (tester) async {
        await rerun(
          tester,
          _Repo(
            past: [routine('p1', '어제 한 일')],
            duplicated: routine('p2', title),
          ),
        );
        expect(find.text('⟦todayRoutineCopied($title)⟧'), findsOneWidget);
      });
    }
  });

  group('홈 코치마크', () {
    testWidgets('세 단계가 각자의 키를 읽는다', (tester) async {
      final storage = InMemoryStorage(
        onboardingCompleted: true,
        nickname: '하늘이',
        homeCoachSeen: false,
      );
      final router = GoRouter(
        initialLocation: Routes.guardian,
        routes: [
          GoRoute(
            path: Routes.guardian,
            builder: (context, state) => const GuardianHomeScreen(),
          ),
        ],
      );
      await pumpSpy(
        tester,
        const SizedBox.shrink(),
        router: router,
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          routineRepositoryProvider.overrideWithValue(
            _Repo(
              today: [
                Routine(
                  id: 'a',
                  title: '손 씻기',
                  status: 'CONFIRMED',
                  steps: [
                    ActionCard(id: 'a-1', stepOrder: 1, description: '첫 단계'),
                  ],
                ),
              ],
            ),
          ),
          memberProvider.overrideWith(
            (ref) async => const Member(nickname: '하늘이'),
          ),
        ],
      );
      // 목록을 받아 오고 홈이 잠시 가만히 있은 뒤 코치마크가 막을 올린다
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expectMarkers(tester, const ['⟦homeCoachCreate⟧']);

      // 눌러서 다음 단계로 넘긴다
      Future<void> next() async {
        await tester.tapAt(const Offset(200, 760));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
      }

      await next();
      expectMarkers(tester, const ['⟦homeCoachSwipe⟧']);
      await next();
      expectMarkers(tester, const ['⟦homeCoachSwitch⟧']);
    });
  });

  test('이 파일의 시험이 화면에서 확인하는 키는 중복 없이 이 작업의 새 키 전부다', () {
    final checked = {
      for (final list in _everyChecked)
        for (final marker in list) keyOf(marker),
    };
    // 글자로 안 보이는 배경 막 이름은 위 카드 크게 보기 시험이 막 위젯에서 따로 읽는다
    checked.add('cardViewerBarrierLabel');

    final arb =
        (jsonDecode(File('lib/l10n/app_ko.arb').readAsStringSync())
                as Map<String, dynamic>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();

    expect(
      checked.difference(arb),
      isEmpty,
      reason: '시험이 읽는다고 적은 키가 ARB 에 없다 (오타)',
    );
    // 이 작업이 새로 만든 키(공용·이전 작업의 키를 재사용한 commonConfirm 등은 뺀다)
    const reused = {
      'commonClose',
      'commonConfirm',
      'commonCancel',
      'commonRetryLater',
      'cardPhotoTooLarge',
    };
    expect(checked.difference(reused).length, 103);
  });
}

/// 설정 열기를 정해 둔 대로 돌려주는 가짜.
class _Settings implements PhotoSettings {
  _Settings({this.available = false, this.opens = true});

  @override
  final bool available;
  final bool opens;

  @override
  Future<bool> open() async => opens;
}

class _Speech implements SpeechService {
  _Speech({required this.ok});

  final bool ok;

  @override
  Future<bool> speak(String text, {String language = 'ko'}) async => ok;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// 정해 둔 응답만 주는 일과 저장소. 쓰지 않는 메서드를 부르면 시험이 실패한다.
class _Repo with FakeRewardApi implements RoutineRepository {
  _Repo({
    this.today = const [],
    this.past = const [],
    this.todayError,
    this.pastError,
    this.deleteFailure,
    this.reorderFailure,
    this.duplicateFailure,
    this.duplicated,
    this.reorderStepsFails = false,
  });

  final List<Routine> today;
  final List<Routine> past;
  final AppFailure? todayError;
  final AppFailure? pastError;
  final AppFailure? deleteFailure;
  final AppFailure? reorderFailure;
  final AppFailure? duplicateFailure;
  final Routine? duplicated;
  final bool reorderStepsFails;

  @override
  Future<List<Routine>> getMyRoutines() async => today;

  @override
  Future<List<Routine>> getTodayRoutines() async {
    final error = todayError;
    if (error != null) throw error;
    return today;
  }

  @override
  Future<List<Routine>> getPastRoutines() async {
    final error = pastError;
    if (error != null) throw error;
    return past;
  }

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];

  @override
  Future<AppFailure?> delete(String routineId) async => deleteFailure;

  @override
  Future<AppFailure?> reorder(List<String> routineIds) async => reorderFailure;

  @override
  Future<Attempt<Routine>> duplicate(String routineId) async {
    final failure = duplicateFailure;
    if (failure != null) return Attempt.failed(failure);
    return Attempt.ok(duplicated ?? past.first);
  }

  @override
  Future<AppFailure?> reorderSteps(
    String routineId,
    List<String> stepIds,
  ) async =>
      reorderStepsFails ? const AppFailure(fault: NetworkFault.app) : null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} 은 이 시험에서 쓰지 않는다');
}
