// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'routine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Routine {

 String get id;/// AI가 붙인 제목 (예: "비 오는 날 학교 가기")
 String get title;/// 보호자가 입력한 원문 — 마스킹 **전**. 화면 비교용으로만 쓴다.
 String get rawInputText;/// 민감정보를 카테고리 태그로 치환한 텍스트 — 실제 LLM에 전달된 값.
/// 발표의 "전송 전/후 비교" 장면이 이 필드로 성립한다.
 String get sanitizedInputText;/// 상태 (`PENDING_REVIEW` / `CONFIRMED` / `COMPLETED` 등)
 String get status; List<ActionCard> get steps;// --- 진행률 (이슈 #75, GET /api/routines/today) ---
// 서버가 미리 계산해 내려준다. 옛 엔드포인트 응답에는 없어 0이 기본이다.
/// 완료한 단계 수. 서버 `completedStepCount`.
 int get completedStepCount;/// 전체 단계 수. 서버 `totalStepCount`.
 int get totalStepCount;/// 진행률(정수 %). 서버 `progressPercent`.
 int get progressPercent;
/// Create a copy of Routine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoutineCopyWith<Routine> get copyWith => _$RoutineCopyWithImpl<Routine>(this as Routine, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Routine&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.rawInputText, rawInputText) || other.rawInputText == rawInputText)&&(identical(other.sanitizedInputText, sanitizedInputText) || other.sanitizedInputText == sanitizedInputText)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.steps, steps)&&(identical(other.completedStepCount, completedStepCount) || other.completedStepCount == completedStepCount)&&(identical(other.totalStepCount, totalStepCount) || other.totalStepCount == totalStepCount)&&(identical(other.progressPercent, progressPercent) || other.progressPercent == progressPercent));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,rawInputText,sanitizedInputText,status,const DeepCollectionEquality().hash(steps),completedStepCount,totalStepCount,progressPercent);

@override
String toString() {
  return 'Routine(id: $id, title: $title, rawInputText: $rawInputText, sanitizedInputText: $sanitizedInputText, status: $status, steps: $steps, completedStepCount: $completedStepCount, totalStepCount: $totalStepCount, progressPercent: $progressPercent)';
}


}

/// @nodoc
abstract mixin class $RoutineCopyWith<$Res>  {
  factory $RoutineCopyWith(Routine value, $Res Function(Routine) _then) = _$RoutineCopyWithImpl;
@useResult
$Res call({
 String id, String title, String rawInputText, String sanitizedInputText, String status, List<ActionCard> steps, int completedStepCount, int totalStepCount, int progressPercent
});




}
/// @nodoc
class _$RoutineCopyWithImpl<$Res>
    implements $RoutineCopyWith<$Res> {
  _$RoutineCopyWithImpl(this._self, this._then);

  final Routine _self;
  final $Res Function(Routine) _then;

/// Create a copy of Routine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? rawInputText = null,Object? sanitizedInputText = null,Object? status = null,Object? steps = null,Object? completedStepCount = null,Object? totalStepCount = null,Object? progressPercent = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,rawInputText: null == rawInputText ? _self.rawInputText : rawInputText // ignore: cast_nullable_to_non_nullable
as String,sanitizedInputText: null == sanitizedInputText ? _self.sanitizedInputText : sanitizedInputText // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as List<ActionCard>,completedStepCount: null == completedStepCount ? _self.completedStepCount : completedStepCount // ignore: cast_nullable_to_non_nullable
as int,totalStepCount: null == totalStepCount ? _self.totalStepCount : totalStepCount // ignore: cast_nullable_to_non_nullable
as int,progressPercent: null == progressPercent ? _self.progressPercent : progressPercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Routine].
extension RoutinePatterns on Routine {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Routine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Routine() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Routine value)  $default,){
final _that = this;
switch (_that) {
case _Routine():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Routine value)?  $default,){
final _that = this;
switch (_that) {
case _Routine() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String rawInputText,  String sanitizedInputText,  String status,  List<ActionCard> steps,  int completedStepCount,  int totalStepCount,  int progressPercent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Routine() when $default != null:
return $default(_that.id,_that.title,_that.rawInputText,_that.sanitizedInputText,_that.status,_that.steps,_that.completedStepCount,_that.totalStepCount,_that.progressPercent);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String rawInputText,  String sanitizedInputText,  String status,  List<ActionCard> steps,  int completedStepCount,  int totalStepCount,  int progressPercent)  $default,) {final _that = this;
switch (_that) {
case _Routine():
return $default(_that.id,_that.title,_that.rawInputText,_that.sanitizedInputText,_that.status,_that.steps,_that.completedStepCount,_that.totalStepCount,_that.progressPercent);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String rawInputText,  String sanitizedInputText,  String status,  List<ActionCard> steps,  int completedStepCount,  int totalStepCount,  int progressPercent)?  $default,) {final _that = this;
switch (_that) {
case _Routine() when $default != null:
return $default(_that.id,_that.title,_that.rawInputText,_that.sanitizedInputText,_that.status,_that.steps,_that.completedStepCount,_that.totalStepCount,_that.progressPercent);case _:
  return null;

}
}

}

/// @nodoc


class _Routine extends Routine {
  const _Routine({required this.id, this.title = '', this.rawInputText = '', this.sanitizedInputText = '', this.status = '', final  List<ActionCard> steps = const <ActionCard>[], this.completedStepCount = 0, this.totalStepCount = 0, this.progressPercent = 0}): _steps = steps,super._();
  

@override final  String id;
/// AI가 붙인 제목 (예: "비 오는 날 학교 가기")
@override@JsonKey() final  String title;
/// 보호자가 입력한 원문 — 마스킹 **전**. 화면 비교용으로만 쓴다.
@override@JsonKey() final  String rawInputText;
/// 민감정보를 카테고리 태그로 치환한 텍스트 — 실제 LLM에 전달된 값.
/// 발표의 "전송 전/후 비교" 장면이 이 필드로 성립한다.
@override@JsonKey() final  String sanitizedInputText;
/// 상태 (`PENDING_REVIEW` / `CONFIRMED` / `COMPLETED` 등)
@override@JsonKey() final  String status;
 final  List<ActionCard> _steps;
@override@JsonKey() List<ActionCard> get steps {
  if (_steps is EqualUnmodifiableListView) return _steps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_steps);
}

// --- 진행률 (이슈 #75, GET /api/routines/today) ---
// 서버가 미리 계산해 내려준다. 옛 엔드포인트 응답에는 없어 0이 기본이다.
/// 완료한 단계 수. 서버 `completedStepCount`.
@override@JsonKey() final  int completedStepCount;
/// 전체 단계 수. 서버 `totalStepCount`.
@override@JsonKey() final  int totalStepCount;
/// 진행률(정수 %). 서버 `progressPercent`.
@override@JsonKey() final  int progressPercent;

/// Create a copy of Routine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoutineCopyWith<_Routine> get copyWith => __$RoutineCopyWithImpl<_Routine>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Routine&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.rawInputText, rawInputText) || other.rawInputText == rawInputText)&&(identical(other.sanitizedInputText, sanitizedInputText) || other.sanitizedInputText == sanitizedInputText)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._steps, _steps)&&(identical(other.completedStepCount, completedStepCount) || other.completedStepCount == completedStepCount)&&(identical(other.totalStepCount, totalStepCount) || other.totalStepCount == totalStepCount)&&(identical(other.progressPercent, progressPercent) || other.progressPercent == progressPercent));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,rawInputText,sanitizedInputText,status,const DeepCollectionEquality().hash(_steps),completedStepCount,totalStepCount,progressPercent);

@override
String toString() {
  return 'Routine(id: $id, title: $title, rawInputText: $rawInputText, sanitizedInputText: $sanitizedInputText, status: $status, steps: $steps, completedStepCount: $completedStepCount, totalStepCount: $totalStepCount, progressPercent: $progressPercent)';
}


}

/// @nodoc
abstract mixin class _$RoutineCopyWith<$Res> implements $RoutineCopyWith<$Res> {
  factory _$RoutineCopyWith(_Routine value, $Res Function(_Routine) _then) = __$RoutineCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String rawInputText, String sanitizedInputText, String status, List<ActionCard> steps, int completedStepCount, int totalStepCount, int progressPercent
});




}
/// @nodoc
class __$RoutineCopyWithImpl<$Res>
    implements _$RoutineCopyWith<$Res> {
  __$RoutineCopyWithImpl(this._self, this._then);

  final _Routine _self;
  final $Res Function(_Routine) _then;

/// Create a copy of Routine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? rawInputText = null,Object? sanitizedInputText = null,Object? status = null,Object? steps = null,Object? completedStepCount = null,Object? totalStepCount = null,Object? progressPercent = null,}) {
  return _then(_Routine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,rawInputText: null == rawInputText ? _self.rawInputText : rawInputText // ignore: cast_nullable_to_non_nullable
as String,sanitizedInputText: null == sanitizedInputText ? _self.sanitizedInputText : sanitizedInputText // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,steps: null == steps ? _self._steps : steps // ignore: cast_nullable_to_non_nullable
as List<ActionCard>,completedStepCount: null == completedStepCount ? _self.completedStepCount : completedStepCount // ignore: cast_nullable_to_non_nullable
as int,totalStepCount: null == totalStepCount ? _self.totalStepCount : totalStepCount // ignore: cast_nullable_to_non_nullable
as int,progressPercent: null == progressPercent ? _self.progressPercent : progressPercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$RoutineQuestion {

/// 서버 필드명은 `required`지만 Dart 예약어와 겹쳐 이름을 바꿨다.
/// JSON 파싱에서 'required' 키를 읽는다.
 bool get isRequired; List<QuestionItem> get questions;
/// Create a copy of RoutineQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoutineQuestionCopyWith<RoutineQuestion> get copyWith => _$RoutineQuestionCopyWithImpl<RoutineQuestion>(this as RoutineQuestion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoutineQuestion&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired)&&const DeepCollectionEquality().equals(other.questions, questions));
}


@override
int get hashCode => Object.hash(runtimeType,isRequired,const DeepCollectionEquality().hash(questions));

@override
String toString() {
  return 'RoutineQuestion(isRequired: $isRequired, questions: $questions)';
}


}

/// @nodoc
abstract mixin class $RoutineQuestionCopyWith<$Res>  {
  factory $RoutineQuestionCopyWith(RoutineQuestion value, $Res Function(RoutineQuestion) _then) = _$RoutineQuestionCopyWithImpl;
@useResult
$Res call({
 bool isRequired, List<QuestionItem> questions
});




}
/// @nodoc
class _$RoutineQuestionCopyWithImpl<$Res>
    implements $RoutineQuestionCopyWith<$Res> {
  _$RoutineQuestionCopyWithImpl(this._self, this._then);

  final RoutineQuestion _self;
  final $Res Function(RoutineQuestion) _then;

/// Create a copy of RoutineQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isRequired = null,Object? questions = null,}) {
  return _then(_self.copyWith(
isRequired: null == isRequired ? _self.isRequired : isRequired // ignore: cast_nullable_to_non_nullable
as bool,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<QuestionItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [RoutineQuestion].
extension RoutineQuestionPatterns on RoutineQuestion {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoutineQuestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoutineQuestion() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoutineQuestion value)  $default,){
final _that = this;
switch (_that) {
case _RoutineQuestion():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoutineQuestion value)?  $default,){
final _that = this;
switch (_that) {
case _RoutineQuestion() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isRequired,  List<QuestionItem> questions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoutineQuestion() when $default != null:
return $default(_that.isRequired,_that.questions);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isRequired,  List<QuestionItem> questions)  $default,) {final _that = this;
switch (_that) {
case _RoutineQuestion():
return $default(_that.isRequired,_that.questions);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isRequired,  List<QuestionItem> questions)?  $default,) {final _that = this;
switch (_that) {
case _RoutineQuestion() when $default != null:
return $default(_that.isRequired,_that.questions);case _:
  return null;

}
}

}

/// @nodoc


class _RoutineQuestion extends RoutineQuestion {
  const _RoutineQuestion({this.isRequired = false, final  List<QuestionItem> questions = const <QuestionItem>[]}): _questions = questions,super._();
  

/// 서버 필드명은 `required`지만 Dart 예약어와 겹쳐 이름을 바꿨다.
/// JSON 파싱에서 'required' 키를 읽는다.
@override@JsonKey() final  bool isRequired;
 final  List<QuestionItem> _questions;
@override@JsonKey() List<QuestionItem> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}


/// Create a copy of RoutineQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoutineQuestionCopyWith<_RoutineQuestion> get copyWith => __$RoutineQuestionCopyWithImpl<_RoutineQuestion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoutineQuestion&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired)&&const DeepCollectionEquality().equals(other._questions, _questions));
}


@override
int get hashCode => Object.hash(runtimeType,isRequired,const DeepCollectionEquality().hash(_questions));

@override
String toString() {
  return 'RoutineQuestion(isRequired: $isRequired, questions: $questions)';
}


}

/// @nodoc
abstract mixin class _$RoutineQuestionCopyWith<$Res> implements $RoutineQuestionCopyWith<$Res> {
  factory _$RoutineQuestionCopyWith(_RoutineQuestion value, $Res Function(_RoutineQuestion) _then) = __$RoutineQuestionCopyWithImpl;
@override @useResult
$Res call({
 bool isRequired, List<QuestionItem> questions
});




}
/// @nodoc
class __$RoutineQuestionCopyWithImpl<$Res>
    implements _$RoutineQuestionCopyWith<$Res> {
  __$RoutineQuestionCopyWithImpl(this._self, this._then);

  final _RoutineQuestion _self;
  final $Res Function(_RoutineQuestion) _then;

/// Create a copy of RoutineQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isRequired = null,Object? questions = null,}) {
  return _then(_RoutineQuestion(
isRequired: null == isRequired ? _self.isRequired : isRequired // ignore: cast_nullable_to_non_nullable
as bool,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<QuestionItem>,
  ));
}


}

/// @nodoc
mixin _$QuestionItem {

 String get question; List<String> get options;
/// Create a copy of QuestionItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionItemCopyWith<QuestionItem> get copyWith => _$QuestionItemCopyWithImpl<QuestionItem>(this as QuestionItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionItem&&(identical(other.question, question) || other.question == question)&&const DeepCollectionEquality().equals(other.options, options));
}


@override
int get hashCode => Object.hash(runtimeType,question,const DeepCollectionEquality().hash(options));

@override
String toString() {
  return 'QuestionItem(question: $question, options: $options)';
}


}

/// @nodoc
abstract mixin class $QuestionItemCopyWith<$Res>  {
  factory $QuestionItemCopyWith(QuestionItem value, $Res Function(QuestionItem) _then) = _$QuestionItemCopyWithImpl;
@useResult
$Res call({
 String question, List<String> options
});




}
/// @nodoc
class _$QuestionItemCopyWithImpl<$Res>
    implements $QuestionItemCopyWith<$Res> {
  _$QuestionItemCopyWithImpl(this._self, this._then);

  final QuestionItem _self;
  final $Res Function(QuestionItem) _then;

/// Create a copy of QuestionItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? question = null,Object? options = null,}) {
  return _then(_self.copyWith(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [QuestionItem].
extension QuestionItemPatterns on QuestionItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuestionItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuestionItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuestionItem value)  $default,){
final _that = this;
switch (_that) {
case _QuestionItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuestionItem value)?  $default,){
final _that = this;
switch (_that) {
case _QuestionItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String question,  List<String> options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuestionItem() when $default != null:
return $default(_that.question,_that.options);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String question,  List<String> options)  $default,) {final _that = this;
switch (_that) {
case _QuestionItem():
return $default(_that.question,_that.options);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String question,  List<String> options)?  $default,) {final _that = this;
switch (_that) {
case _QuestionItem() when $default != null:
return $default(_that.question,_that.options);case _:
  return null;

}
}

}

/// @nodoc


class _QuestionItem extends QuestionItem {
  const _QuestionItem({this.question = '', final  List<String> options = const <String>[]}): _options = options,super._();
  

@override@JsonKey() final  String question;
 final  List<String> _options;
@override@JsonKey() List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


/// Create a copy of QuestionItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuestionItemCopyWith<_QuestionItem> get copyWith => __$QuestionItemCopyWithImpl<_QuestionItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuestionItem&&(identical(other.question, question) || other.question == question)&&const DeepCollectionEquality().equals(other._options, _options));
}


@override
int get hashCode => Object.hash(runtimeType,question,const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'QuestionItem(question: $question, options: $options)';
}


}

/// @nodoc
abstract mixin class _$QuestionItemCopyWith<$Res> implements $QuestionItemCopyWith<$Res> {
  factory _$QuestionItemCopyWith(_QuestionItem value, $Res Function(_QuestionItem) _then) = __$QuestionItemCopyWithImpl;
@override @useResult
$Res call({
 String question, List<String> options
});




}
/// @nodoc
class __$QuestionItemCopyWithImpl<$Res>
    implements _$QuestionItemCopyWith<$Res> {
  __$QuestionItemCopyWithImpl(this._self, this._then);

  final _QuestionItem _self;
  final $Res Function(_QuestionItem) _then;

/// Create a copy of QuestionItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? question = null,Object? options = null,}) {
  return _then(_QuestionItem(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
