import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/l10n/batchim.dart';
import '../../core/l10n/current_l10n.dart';
import '../../core/l10n/date_labels.dart';
import 'action_card.dart';
import 'credit_usage.dart';
import 'reward_preset.dart';

part 'routine.freezed.dart';

/// 일과 — 서버 `RoutineResponse`에 대응한다.
///
/// 출처: server/.../routine/application/dto/response/RoutineResponse.java
///
/// ⚠️ [rawInputText]는 **마스킹 전 원문**이다. 로그에 남기지 않는다 (docs 원칙 5번).
@freezed
abstract class Routine with _$Routine {
  const factory Routine({
    required String id,

    /// AI가 붙인 제목 (예: "비 오는 날 학교 가기")
    @Default('') String title,

    /// 보호자가 입력한 원문 — 마스킹 **전**. 화면 비교용으로만 쓴다.
    @Default('') String rawInputText,

    /// 민감정보를 카테고리 태그로 치환한 텍스트 — 실제 LLM에 전달된 값.
    /// 발표의 "전송 전/후 비교" 장면이 이 필드로 성립한다.
    @Default('') String sanitizedInputText,

    /// 상태 (`PENDING_REVIEW` / `CONFIRMED` / `COMPLETED` 등)
    @Default('') String status,
    @Default(<ActionCard>[]) List<ActionCard> steps,

    // --- 진행률 (이슈 #75, GET /api/routines/today) ---
    // 서버가 미리 계산해 내려준다. 옛 엔드포인트 응답에는 없어 0이 기본이다.

    /// 완료한 단계 수. 서버 `completedStepCount`.
    @Default(0) int completedStepCount,

    /// 전체 단계 수. 서버 `totalStepCount`.
    @Default(0) int totalStepCount,

    /// 진행률(정수 %). 서버 `progressPercent`.
    @Default(0) int progressPercent,

    /// 일과를 수행하는 날/시각. 서버 `scheduledAt` (이슈 #258).
    ///
    /// **`지난 일과`에서만 화면에 나온다.** 오늘 일과는 전부 오늘이라 날짜를
    /// 적을 이유가 없고, 지난 목록은 언제 것인지가 없으면 같은 제목이 여러 번
    /// 반복돼 구분되지 않는다.
    DateTime? scheduledAt,

    // --- 보상(강화물) (이슈 #148, 2026-09-13 서울 ABA연구소 자문) ---
    // 보호자가 정하는 선택 항목이다. **비어 있으면 아동 화면에 보상 UI를 띄우지 않는다.**
    // 앱이 보상을 정하지도, 주지도 않는다 — 정하는 것도 주는 것도 보호자다.

    /// 보호자가 정한 보상. 예: "젤리 먹기"
    @Default('') String rewardText,

    /// 보상 프리셋 키(`SNACK`/`VIDEO`/`PLAY`/`WALK`/`CUSTOM`). 직접 입력이면 `CUSTOM` 또는 빈 값.
    @Default('') String rewardPresetKey,

    /// 이번 생성이 쓴 크레딧 (#407). **생성 응답에만 있다** — 캐시([toJson])에
    /// 넣지 않는다. 다시 읽은 일과에 옛 사용량이 붙어 있으면 거짓말이 된다.
    CreditUsage? creditUsage,

    // --- 만든 사람 (다중 보호자 #362 · E30·E46) ---
    // 한 이룸이에 보호자가 여럿이면 일과는 모두가 보지만 승인·수정·삭제는 **만든 사람만** 한다.
    // 서버 `RoutineResponse` 에 이 두 필드가 아직 없다(서버 #361 범위 밖) — 앱은 받을 준비만
    // 해 두고, 없으면 null(알 수 없음)이라 지금처럼 모든 버튼을 보인다. 서버가 최종 판단한다.

    /// 이 일과를 만든 사람이 나인가. null 이면 서버가 알려 주지 않았다.
    bool? createdByMe,

    /// 만든 사람이 이 이룸이 안에서 불리는 이름. 비어 있으면 null.
    String? creatorName,
  }) = _Routine;

  const Routine._();

  /// 내가 고칠 수 있는 일과인가. **남이 만든 것으로 확인된 경우에만 false** 다.
  ///
  /// 만든 사람을 모르면(null) true — 버튼을 숨겨서 내 일과를 못 고치게 하는 것보다 누른 뒤
  /// 서버가 막는 쪽(403 `ROUTINE_NOT_CREATOR`)이 낫다. 서버가 최종 판단한다.
  bool get isEditableByMe => createdByMe != false;

  /// 남이 만든 일과에 붙이는 `엄마가 만든 일과예요`. 내가 만들었거나 모르면 null.
  String? get foreignCreatorLabel {
    if (createdByMe != false) return null;
    final name = creatorName?.trim();
    if (name == null || name.isEmpty) return appL10n.routineForeignCreatorUnknown;
    // 조사 글자는 문구가 정한다 — 코드는 받침 판정값만 넘긴다
    return appL10n.routineForeignCreator(name, batchimOf(name));
  }

  /// 보호자가 승인했는가. 승인 전에는 아동 화면에 노출하지 않는다 (docs 원칙 3번).
  bool get isConfirmed => status == 'CONFIRMED';

  /// 아동 화면에 보여도 되는가. `/today`가 CONFIRMED와 COMPLETED를 함께 주므로
  /// isConfirmed만 걸면 다 끝낸 일과가 목록에서 사라진다 (이슈 #75).
  bool get isVisibleToChild => isConfirmed || status == 'COMPLETED';

  /// [now] 날짜의 오늘 일과로 보여도 되는가 (#353).
  ///
  /// 서버 `/today` 와 같은 규칙이다 — 승인 전(`PENDING_REVIEW`)은 빼고,
  /// `scheduledAt` 이 오늘이어야 한다. 앱이 받아 둔 값(메모리·오프라인 캐시·폴백)은
  /// 서버가 거른 뒤에 날짜가 지났을 수 있어 앱이 한 번 더 거른다.
  /// `scheduledAt` 이 없으면 날짜를 알 수 없어 서버가 거른 것으로 믿는다.
  bool isTodayOn(DateTime now) {
    if (status == 'PENDING_REVIEW') return false;
    final at = scheduledAt;
    if (at == null) return true;
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }

  /// DLP가 실제로 무언가를 바꿨는가.
  /// 둘이 같으면 탐지된 민감정보가 없다는 뜻이다.
  bool get hasMaskedContent =>
      sanitizedInputText.isNotEmpty && rawInputText != sanitizedInputText;

  /// 홈·아이 목록에 보여줄 제목.
  /// AI가 title을 못 만들어도 화면이 비지 않게 대체어를 준다 (docs 원칙 6번).
  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : appL10n.routineDefaultTitle;

  /// 모든 카드를 마쳤는가. 아이 홈 타일의 완료 배경 판단에 쓴다.
  bool get isAllDone => steps.isNotEmpty && steps.every((s) => s.completed);

  /// 이룸이가 다 끝냈는가 (#534). 서버 상태가 늦게 바뀐 응답도 있어 단계로도 본다.
  bool get isFinished => status == 'COMPLETED' || isAllDone;

  /// 이룸이가 한 단계라도 했는가 (#533). 시작한 일과는 서버가 지우지 않는다 —
  /// 수행 기록이고 받은 별이 묶여 있다.
  bool get hasStarted =>
      isFinished || completedStepCount > 0 || steps.any((s) => s.completed);

  /// 보상이 정해져 있는가. **false면 보상 관련 UI를 전부 숨긴다.**
  /// 보상을 정하지 않은 보호자에게 빈 자리를 보여주면 안 한 일처럼 느껴진다.
  bool get hasReward => rewardText.trim().isNotEmpty;

  /// 보상 앞에 붙일 그림. 프리셋을 모르면 기본 그림을 준다.
  String get rewardEmoji => RewardPreset.emojiOf(rewardPresetKey);

  /// 아동 화면 보상 바에 그대로 쓰는 문구. 보상이 없으면 빈 문자열이다.
  ///
  /// **그림이 없으면 글자만 준다** (#275). 빈 그림을 그대로 이어붙이면 문구 앞에
  /// 공백 한 칸이 남아 줄이 밀린다.
  String get rewardDisplay {
    if (!hasReward) return '';
    final text = rewardText.trim();
    final emoji = rewardEmoji;
    return emoji.isEmpty ? text : '$emoji $text';
  }

  /// `지난 일과` 카드에 적는 날짜 (`2026년 9월 20일`). 값이 없으면 빈 문자열이라
  /// 화면에서 그 줄 자체가 사라진다 — `날짜 없음` 같은 문구를 보여주지 않는다.
  String get scheduledDateLabel {
    final at = scheduledAt;
    if (at == null) return '';
    return appL10n.yearMonthDay(at);
  }

  /// 오프라인 캐시 저장용 — [fromJson]과 대칭이어야 한다 (이슈 #140).
  /// 원문(rawInputText)·마스킹본(sanitizedInputText)은 **일부러 넣지 않는다** —
  /// 화면이 읽지 않는 값이고 로컬에 남기면 docs 원칙 5번을 어긴다 (#358).
  /// 그래서 왕복하면 두 필드는 빈 문자열이 된다.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    'steps': steps.map((s) => s.toJson()).toList(),
    'completedStepCount': completedStepCount,
    'totalStepCount': totalStepCount,
    'progressPercent': progressPercent,
    'scheduledAt': scheduledAt?.toIso8601String(),
    'rewardText': rewardText,
    'rewardPresetKey': rewardPresetKey,
    // 오프라인으로 목록을 열어도 남의 일과 버튼이 도로 생기지 않게 남긴다 (#362).
    if (createdByMe != null) 'createdByMe': createdByMe,
    if (creatorName != null) 'creatorName': creatorName,
  };

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      rawInputText: json['rawInputText']?.toString() ?? '',
      sanitizedInputText: json['sanitizedInputText']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      steps: switch (json['steps']) {
        final List<dynamic> list =>
          list
              .whereType<Map<String, dynamic>>()
              .map(ActionCard.fromJson)
              .toList(),
        _ => const <ActionCard>[],
      },
      completedStepCount: _asInt(json['completedStepCount']),
      totalStepCount: _asInt(json['totalStepCount']),
      progressPercent: _asInt(json['progressPercent']),
      // 형식이 어긋나도 null로 떨어뜨린다 — 날짜 한 줄 때문에 목록이 죽으면 안 된다.
      scheduledAt: DateTime.tryParse(json['scheduledAt']?.toString() ?? ''),
      // 서버는 보상 미설정 시 null을 준다. 빈 문자열로 받아 hasReward가 false가 되게 한다.
      rewardText: json['rewardText']?.toString() ?? '',
      rewardPresetKey: json['rewardPresetKey']?.toString() ?? '',
      // 크레딧이 꺼져 있거나 모양이 다르면 null — 사용량 줄을 그리지 않는다.
      creditUsage: CreditUsage.tryParse(json['credit']),
      // bool 이 아니면 모른다 — 문자열 `yes` 같은 모양을 참으로 읽지 않는다.
      createdByMe: json['createdByMe'] is bool
          ? json['createdByMe'] as bool
          : null,
      creatorName: json['creatorName']?.toString(),
    );
  }

  /// 숫자가 int·String 어느 쪽으로 와도 죽지 않게 읽는다.
  static int _asInt(Object? value) => switch (value) {
    final int v => v,
    final String v => int.tryParse(v) ?? 0,
    _ => 0,
  };
}

/// 최근에 정한 보상 — 서버 `RecentRewardResponse`에 대응.
///
/// 보상 설정 화면 상단의 "최근에 정한 보상"에 쓴다. 같은 보상을 다시 고르는 경우가
/// 대부분이라, 두 번째 일과부터는 탭 한 번으로 끝나게 하는 것이 목적이다.
///
/// **첫 일과에서는 빈 목록이 온다.** 그때는 화면에서 섹션 자체를 숨긴다 —
/// 빈 영역을 남겨두면 로딩에 실패한 것처럼 보인다.
class RecentReward {
  const RecentReward({this.rewardText = '', this.rewardPresetKey = ''});

  final String rewardText;

  /// 프리셋 키. 보호자가 직접 적었으면 `CUSTOM`이거나 비어 있다.
  final String rewardPresetKey;

  /// 칩으로 띄울 수 있는 값인가. 서버가 빈 문자열을 줄 수도 있다.
  bool get isValid => rewardText.trim().isNotEmpty;

  String get emoji => RewardPreset.emojiOf(rewardPresetKey);

  factory RecentReward.fromJson(Map<String, dynamic> json) => RecentReward(
    rewardText: json['rewardText']?.toString() ?? '',
    rewardPresetKey: json['rewardPresetKey']?.toString() ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is RecentReward &&
      other.rewardText == rewardText &&
      other.rewardPresetKey == rewardPresetKey;

  @override
  int get hashCode => Object.hash(rewardText, rewardPresetKey);
}

/// AI 추가 질문 — 서버 `RoutineQuestionResponse`에 대응.
///
/// 서버는 이 엔드포인트가 **실패해도 항상 200**을 준다.
/// [isRequired]가 false면 질문 단계를 건너뛰고 바로 카드 생성으로 간다.
///
/// ⚠️ 서버가 **질문 여러 개**를 준다. 선택한 도움 목표마다 하나씩 나온다.
/// 예전에는 단일 질문이었으나 계약이 바뀌었다.
/// 출처: server/.../dto/response/RoutineQuestionResponse.java
@freezed
abstract class RoutineQuestion with _$RoutineQuestion {
  const factory RoutineQuestion({
    /// 서버 필드명은 `required`지만 Dart 예약어와 겹쳐 이름을 바꿨다.
    /// JSON 파싱에서 'required' 키를 읽는다.
    @Default(false) bool isRequired,
    @Default(<QuestionItem>[]) List<QuestionItem> questions,
  }) = _RoutineQuestion;

  const RoutineQuestion._();

  /// 질문을 실제로 보여줄 수 있는 상태인가.
  /// required가 true여도 질문이 비어 오면 물어볼 것이 없다.
  bool get canAsk => isRequired && questions.any((q) => q.isValid);

  /// 보여줄 수 있는 질문만 남긴다
  List<QuestionItem> get askable => questions.where((q) => q.isValid).toList();

  factory RoutineQuestion.fromJson(Map<String, dynamic> json) {
    return RoutineQuestion(
      isRequired: json['required'] == true,
      questions: switch (json['questions']) {
        final List<dynamic> list =>
          list
              .whereType<Map<String, dynamic>>()
              .map(QuestionItem.fromJson)
              .toList(),
        _ => const <QuestionItem>[],
      },
    );
  }
}

/// 질문 한 개 — 서버 `RoutineQuestionResponse.QuestionItem`.
@freezed
abstract class QuestionItem with _$QuestionItem {
  const factory QuestionItem({
    @Default('') String question,
    @Default(<QuestionOption>[]) List<QuestionOption> options,
  }) = _QuestionItem;

  const QuestionItem._();

  /// 화면에 띄울 수 있는 질문인가
  bool get isValid => question.trim().isNotEmpty;

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    return QuestionItem(
      question: json['question']?.toString() ?? '',
      options: switch (json['options']) {
        final List<dynamic> list =>
          list
              .whereType<Map<String, dynamic>>()
              .map(QuestionOption.fromJson)
              .toList(),
        _ => const <QuestionOption>[],
      },
    );
  }
}

/// 선택지 한 개 — 서버 `RoutineQuestionResponse.QuestionItem.OptionItem`.
///
/// 서버는 emoji/label을 분리해서 준다. 이걸 통째로 `.toString()`하면
/// `{emoji: 🏫, label: 학교...}` 같은 Map 문자열이 그대로 화면에 노출된다
/// (실제로 발생했던 버그 — 이슈 참고). [label]만 선택값·서버 전송에 쓰고,
/// [displayLabel]은 화면 표시 전용이다.
@freezed
abstract class QuestionOption with _$QuestionOption {
  const factory QuestionOption({
    @Default('') String emoji,
    @Default('') String label,
  }) = _QuestionOption;

  const QuestionOption._();

  /// Figma는 이모지와 라벨을 한 텍스트로 붙여 보여준다(예: "☂️ 우산").
  String get displayLabel => emoji.isEmpty ? label : '$emoji $label';

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      emoji: json['emoji']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}
