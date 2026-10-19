import '../../../l10n/app_localizations.dart';
import 'routine_template.dart';

/// 예시 일과 목록 (#777). 카테고리 순서 > 처음이라면 추천 먼저
///
/// 서버 추천 일과(`RoutineSuggestionCatalog`)와 따로 둔다 — 서버 배포 없이 실증 2차(10/20)에 쓰기 위함.
/// 서버로 옮기면 이 목록을 지우고 응답으로 바꾼다.
const routineTemplates = <RoutineTemplate>[
  RoutineTemplate(
    id: 'brushTeeth',
    category: RoutineTemplateCategory.selfCare,
    icon: '🪥',
    isBeginnerFriendly: true,
    text: _brushTeethText,
    prompt: _brushTeethPrompt,
  ),
  RoutineTemplate(
    id: 'washFace',
    category: RoutineTemplateCategory.selfCare,
    icon: '🧼',
    isBeginnerFriendly: true,
    text: _washFaceText,
    prompt: _washFacePrompt,
  ),
  RoutineTemplate(
    id: 'getDressed',
    category: RoutineTemplateCategory.selfCare,
    icon: '👕',
    isBeginnerFriendly: false,
    text: _getDressedText,
    prompt: _getDressedPrompt,
  ),
  RoutineTemplate(
    id: 'eatMeal',
    category: RoutineTemplateCategory.selfCare,
    icon: '🍚',
    isBeginnerFriendly: false,
    text: _eatMealText,
    prompt: _eatMealPrompt,
  ),
  RoutineTemplate(
    id: 'bathTime',
    category: RoutineTemplateCategory.selfCare,
    icon: '🛁',
    isBeginnerFriendly: false,
    text: _bathTimeText,
    prompt: _bathTimePrompt,
  ),
  RoutineTemplate(
    id: 'morningRoutine',
    category: RoutineTemplateCategory.dailyFlow,
    icon: '🌅',
    isBeginnerFriendly: true,
    text: _morningRoutineText,
    prompt: _morningRoutinePrompt,
  ),
  RoutineTemplate(
    id: 'afterSchool',
    category: RoutineTemplateCategory.dailyFlow,
    icon: '🏠',
    isBeginnerFriendly: false,
    text: _afterSchoolText,
    prompt: _afterSchoolPrompt,
  ),
  RoutineTemplate(
    id: 'bedtime',
    category: RoutineTemplateCategory.dailyFlow,
    icon: '🌙',
    isBeginnerFriendly: false,
    text: _bedtimeText,
    prompt: _bedtimePrompt,
  ),
  RoutineTemplate(
    id: 'goingOut',
    category: RoutineTemplateCategory.dailyFlow,
    icon: '👟',
    isBeginnerFriendly: false,
    text: _goingOutText,
    prompt: _goingOutPrompt,
  ),
  RoutineTemplate(
    id: 'tidyRoom',
    category: RoutineTemplateCategory.household,
    icon: '🧸',
    isBeginnerFriendly: true,
    text: _tidyRoomText,
    prompt: _tidyRoomPrompt,
  ),
  RoutineTemplate(
    id: 'clearDishes',
    category: RoutineTemplateCategory.household,
    icon: '🍽️',
    isBeginnerFriendly: true,
    text: _clearDishesText,
    prompt: _clearDishesPrompt,
  ),
  RoutineTemplate(
    id: 'foldLaundry',
    category: RoutineTemplateCategory.household,
    icon: '🧺',
    isBeginnerFriendly: false,
    text: _foldLaundryText,
    prompt: _foldLaundryPrompt,
  ),
  RoutineTemplate(
    id: 'takeOutTrash',
    category: RoutineTemplateCategory.household,
    icon: '🗑️',
    isBeginnerFriendly: false,
    text: _takeOutTrashText,
    prompt: _takeOutTrashPrompt,
  ),
  RoutineTemplate(
    id: 'rideBus',
    category: RoutineTemplateCategory.community,
    icon: '🚌',
    isBeginnerFriendly: false,
    text: _rideBusText,
    prompt: _rideBusPrompt,
  ),
  RoutineTemplate(
    id: 'buyItem',
    category: RoutineTemplateCategory.community,
    icon: '🛒',
    isBeginnerFriendly: true,
    text: _buyItemText,
    prompt: _buyItemPrompt,
  ),
  RoutineTemplate(
    id: 'useElevator',
    category: RoutineTemplateCategory.community,
    icon: '🛗',
    isBeginnerFriendly: false,
    text: _useElevatorText,
    prompt: _useElevatorPrompt,
  ),
  RoutineTemplate(
    id: 'hospitalVisit',
    category: RoutineTemplateCategory.community,
    icon: '🏥',
    isBeginnerFriendly: false,
    text: _hospitalVisitText,
    prompt: _hospitalVisitPrompt,
  ),
  RoutineTemplate(
    id: 'startHomework',
    category: RoutineTemplateCategory.learning,
    icon: '✏️',
    isBeginnerFriendly: true,
    text: _startHomeworkText,
    prompt: _startHomeworkPrompt,
  ),
  RoutineTemplate(
    id: 'writeName',
    category: RoutineTemplateCategory.learning,
    icon: '🖍️',
    isBeginnerFriendly: false,
    text: _writeNameText,
    prompt: _writeNamePrompt,
  ),
  RoutineTemplate(
    id: 'countObjects',
    category: RoutineTemplateCategory.learning,
    icon: '🔢',
    isBeginnerFriendly: false,
    text: _countObjectsText,
    prompt: _countObjectsPrompt,
  ),
  RoutineTemplate(
    id: 'readBook',
    category: RoutineTemplateCategory.learning,
    icon: '📖',
    isBeginnerFriendly: false,
    text: _readBookText,
    prompt: _readBookPrompt,
  ),
  RoutineTemplate(
    id: 'emotionCard',
    category: RoutineTemplateCategory.feelings,
    icon: '😤',
    isBeginnerFriendly: true,
    text: _emotionCardText,
    prompt: _emotionCardPrompt,
  ),
  RoutineTemplate(
    id: 'playNicely',
    category: RoutineTemplateCategory.feelings,
    icon: '🤝',
    isBeginnerFriendly: false,
    text: _playNicelyText,
    prompt: _playNicelyPrompt,
  ),
  RoutineTemplate(
    id: 'greeting',
    category: RoutineTemplateCategory.feelings,
    icon: '👋',
    isBeginnerFriendly: true,
    text: _greetingText,
    prompt: _greetingPrompt,
  ),
  RoutineTemplate(
    id: 'waitTurn',
    category: RoutineTemplateCategory.feelings,
    icon: '⏳',
    isBeginnerFriendly: false,
    text: _waitTurnText,
    prompt: _waitTurnPrompt,
  ),
  RoutineTemplate(
    id: 'askHelp',
    category: RoutineTemplateCategory.feelings,
    icon: '🙋',
    isBeginnerFriendly: false,
    text: _askHelpText,
    prompt: _askHelpPrompt,
  ),
];

/// [category] 의 예시 일과 (처음이라면 추천이 앞)
List<RoutineTemplate> routineTemplatesOf(RoutineTemplateCategory category) {
  final inCategory = routineTemplates.where((t) => t.category == category);
  return [
    ...inCategory.where((t) => t.isBeginnerFriendly),
    ...inCategory.where((t) => !t.isBeginnerFriendly),
  ];
}

// 문구 접근자 (const 목록에 넣으려고 최상위 함수로 둔다)
String _brushTeethText(AppLocalizations l10n) =>
    l10n.routineTemplateBrushTeethText;
String _brushTeethPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateBrushTeethPrompt;
String _washFaceText(AppLocalizations l10n) => l10n.routineTemplateWashFaceText;
String _washFacePrompt(AppLocalizations l10n) =>
    l10n.routineTemplateWashFacePrompt;
String _getDressedText(AppLocalizations l10n) =>
    l10n.routineTemplateGetDressedText;
String _getDressedPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateGetDressedPrompt;
String _eatMealText(AppLocalizations l10n) => l10n.routineTemplateEatMealText;
String _eatMealPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateEatMealPrompt;
String _bathTimeText(AppLocalizations l10n) => l10n.routineTemplateBathTimeText;
String _bathTimePrompt(AppLocalizations l10n) =>
    l10n.routineTemplateBathTimePrompt;
String _morningRoutineText(AppLocalizations l10n) =>
    l10n.routineTemplateMorningRoutineText;
String _morningRoutinePrompt(AppLocalizations l10n) =>
    l10n.routineTemplateMorningRoutinePrompt;
String _afterSchoolText(AppLocalizations l10n) =>
    l10n.routineTemplateAfterSchoolText;
String _afterSchoolPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateAfterSchoolPrompt;
String _bedtimeText(AppLocalizations l10n) => l10n.routineTemplateBedtimeText;
String _bedtimePrompt(AppLocalizations l10n) =>
    l10n.routineTemplateBedtimePrompt;
String _goingOutText(AppLocalizations l10n) => l10n.routineTemplateGoingOutText;
String _goingOutPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateGoingOutPrompt;
String _tidyRoomText(AppLocalizations l10n) => l10n.routineTemplateTidyRoomText;
String _tidyRoomPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateTidyRoomPrompt;
String _clearDishesText(AppLocalizations l10n) =>
    l10n.routineTemplateClearDishesText;
String _clearDishesPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateClearDishesPrompt;
String _foldLaundryText(AppLocalizations l10n) =>
    l10n.routineTemplateFoldLaundryText;
String _foldLaundryPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateFoldLaundryPrompt;
String _takeOutTrashText(AppLocalizations l10n) =>
    l10n.routineTemplateTakeOutTrashText;
String _takeOutTrashPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateTakeOutTrashPrompt;
String _rideBusText(AppLocalizations l10n) => l10n.routineTemplateRideBusText;
String _rideBusPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateRideBusPrompt;
String _buyItemText(AppLocalizations l10n) => l10n.routineTemplateBuyItemText;
String _buyItemPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateBuyItemPrompt;
String _useElevatorText(AppLocalizations l10n) =>
    l10n.routineTemplateUseElevatorText;
String _useElevatorPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateUseElevatorPrompt;
String _hospitalVisitText(AppLocalizations l10n) =>
    l10n.routineTemplateHospitalVisitText;
String _hospitalVisitPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateHospitalVisitPrompt;
String _startHomeworkText(AppLocalizations l10n) =>
    l10n.routineTemplateStartHomeworkText;
String _startHomeworkPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateStartHomeworkPrompt;
String _writeNameText(AppLocalizations l10n) =>
    l10n.routineTemplateWriteNameText;
String _writeNamePrompt(AppLocalizations l10n) =>
    l10n.routineTemplateWriteNamePrompt;
String _countObjectsText(AppLocalizations l10n) =>
    l10n.routineTemplateCountObjectsText;
String _countObjectsPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateCountObjectsPrompt;
String _readBookText(AppLocalizations l10n) => l10n.routineTemplateReadBookText;
String _readBookPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateReadBookPrompt;
String _emotionCardText(AppLocalizations l10n) =>
    l10n.routineTemplateEmotionCardText;
String _emotionCardPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateEmotionCardPrompt;
String _playNicelyText(AppLocalizations l10n) =>
    l10n.routineTemplatePlayNicelyText;
String _playNicelyPrompt(AppLocalizations l10n) =>
    l10n.routineTemplatePlayNicelyPrompt;
String _greetingText(AppLocalizations l10n) => l10n.routineTemplateGreetingText;
String _greetingPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateGreetingPrompt;
String _waitTurnText(AppLocalizations l10n) => l10n.routineTemplateWaitTurnText;
String _waitTurnPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateWaitTurnPrompt;
String _askHelpText(AppLocalizations l10n) => l10n.routineTemplateAskHelpText;
String _askHelpPrompt(AppLocalizations l10n) =>
    l10n.routineTemplateAskHelpPrompt;
