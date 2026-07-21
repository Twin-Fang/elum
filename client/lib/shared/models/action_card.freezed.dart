// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'action_card.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ActionCard {

 String get id;/// 아동에게 보여줄 짧은 문장 (TTS로도 읽힌다). 서버 `description`.
 String get description;/// 카드 제목 — Figma가 제목과 설명을 나눠 보여준다(`옷을 입어요` /
/// `학교에 갈 옷을 차례대로 입어요`).
///
/// **서버는 아직 주지 않는다.** `RoutineStepResponse`에 제목이 없어
/// 로컬 카드에서만 채워진다. 비어 있으면 화면이 [description]을 대신 쓴다.
 String get title;/// 수행 순서. 서버 `stepOrder`.
 int get stepOrder;/// 카드 이미지 경로. 서버 `imagePath`.
 String? get imagePath;/// 수행 완료 여부. 서버 `completed`.
 bool get completed;
/// Create a copy of ActionCard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActionCardCopyWith<ActionCard> get copyWith => _$ActionCardCopyWithImpl<ActionCard>(this as ActionCard, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActionCard&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.title, title) || other.title == title)&&(identical(other.stepOrder, stepOrder) || other.stepOrder == stepOrder)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.completed, completed) || other.completed == completed));
}


@override
int get hashCode => Object.hash(runtimeType,id,description,title,stepOrder,imagePath,completed);

@override
String toString() {
  return 'ActionCard(id: $id, description: $description, title: $title, stepOrder: $stepOrder, imagePath: $imagePath, completed: $completed)';
}


}

/// @nodoc
abstract mixin class $ActionCardCopyWith<$Res>  {
  factory $ActionCardCopyWith(ActionCard value, $Res Function(ActionCard) _then) = _$ActionCardCopyWithImpl;
@useResult
$Res call({
 String id, String description, String title, int stepOrder, String? imagePath, bool completed
});




}
/// @nodoc
class _$ActionCardCopyWithImpl<$Res>
    implements $ActionCardCopyWith<$Res> {
  _$ActionCardCopyWithImpl(this._self, this._then);

  final ActionCard _self;
  final $Res Function(ActionCard) _then;

/// Create a copy of ActionCard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? description = null,Object? title = null,Object? stepOrder = null,Object? imagePath = freezed,Object? completed = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,stepOrder: null == stepOrder ? _self.stepOrder : stepOrder // ignore: cast_nullable_to_non_nullable
as int,imagePath: freezed == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String?,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ActionCard].
extension ActionCardPatterns on ActionCard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActionCard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActionCard() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActionCard value)  $default,){
final _that = this;
switch (_that) {
case _ActionCard():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActionCard value)?  $default,){
final _that = this;
switch (_that) {
case _ActionCard() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String description,  String title,  int stepOrder,  String? imagePath,  bool completed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActionCard() when $default != null:
return $default(_that.id,_that.description,_that.title,_that.stepOrder,_that.imagePath,_that.completed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String description,  String title,  int stepOrder,  String? imagePath,  bool completed)  $default,) {final _that = this;
switch (_that) {
case _ActionCard():
return $default(_that.id,_that.description,_that.title,_that.stepOrder,_that.imagePath,_that.completed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String description,  String title,  int stepOrder,  String? imagePath,  bool completed)?  $default,) {final _that = this;
switch (_that) {
case _ActionCard() when $default != null:
return $default(_that.id,_that.description,_that.title,_that.stepOrder,_that.imagePath,_that.completed);case _:
  return null;

}
}

}

/// @nodoc


class _ActionCard extends ActionCard {
  const _ActionCard({required this.id, required this.description, this.title = '', this.stepOrder = 0, this.imagePath, this.completed = false}): super._();
  

@override final  String id;
/// 아동에게 보여줄 짧은 문장 (TTS로도 읽힌다). 서버 `description`.
@override final  String description;
/// 카드 제목 — Figma가 제목과 설명을 나눠 보여준다(`옷을 입어요` /
/// `학교에 갈 옷을 차례대로 입어요`).
///
/// **서버는 아직 주지 않는다.** `RoutineStepResponse`에 제목이 없어
/// 로컬 카드에서만 채워진다. 비어 있으면 화면이 [description]을 대신 쓴다.
@override@JsonKey() final  String title;
/// 수행 순서. 서버 `stepOrder`.
@override@JsonKey() final  int stepOrder;
/// 카드 이미지 경로. 서버 `imagePath`.
@override final  String? imagePath;
/// 수행 완료 여부. 서버 `completed`.
@override@JsonKey() final  bool completed;

/// Create a copy of ActionCard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActionCardCopyWith<_ActionCard> get copyWith => __$ActionCardCopyWithImpl<_ActionCard>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActionCard&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.title, title) || other.title == title)&&(identical(other.stepOrder, stepOrder) || other.stepOrder == stepOrder)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.completed, completed) || other.completed == completed));
}


@override
int get hashCode => Object.hash(runtimeType,id,description,title,stepOrder,imagePath,completed);

@override
String toString() {
  return 'ActionCard(id: $id, description: $description, title: $title, stepOrder: $stepOrder, imagePath: $imagePath, completed: $completed)';
}


}

/// @nodoc
abstract mixin class _$ActionCardCopyWith<$Res> implements $ActionCardCopyWith<$Res> {
  factory _$ActionCardCopyWith(_ActionCard value, $Res Function(_ActionCard) _then) = __$ActionCardCopyWithImpl;
@override @useResult
$Res call({
 String id, String description, String title, int stepOrder, String? imagePath, bool completed
});




}
/// @nodoc
class __$ActionCardCopyWithImpl<$Res>
    implements _$ActionCardCopyWith<$Res> {
  __$ActionCardCopyWithImpl(this._self, this._then);

  final _ActionCard _self;
  final $Res Function(_ActionCard) _then;

/// Create a copy of ActionCard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? description = null,Object? title = null,Object? stepOrder = null,Object? imagePath = freezed,Object? completed = null,}) {
  return _then(_ActionCard(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,stepOrder: null == stepOrder ? _self.stepOrder : stepOrder // ignore: cast_nullable_to_non_nullable
as int,imagePath: freezed == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String?,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
