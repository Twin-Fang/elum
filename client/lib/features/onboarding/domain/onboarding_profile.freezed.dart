// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OnboardingProfile {

/// 아이 호칭. 실명이 아니어도 된다고 온보딩에서 안내한다.
 String get childNickname; Set<SupportGoal> get supportGoals; CardCharacter? get cardCharacter;/// 보호자 모드 전환용 4자리 PIN
 String get guardianPin;
/// Create a copy of OnboardingProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingProfileCopyWith<OnboardingProfile> get copyWith => _$OnboardingProfileCopyWithImpl<OnboardingProfile>(this as OnboardingProfile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingProfile&&(identical(other.childNickname, childNickname) || other.childNickname == childNickname)&&const DeepCollectionEquality().equals(other.supportGoals, supportGoals)&&(identical(other.cardCharacter, cardCharacter) || other.cardCharacter == cardCharacter)&&(identical(other.guardianPin, guardianPin) || other.guardianPin == guardianPin));
}


@override
int get hashCode => Object.hash(runtimeType,childNickname,const DeepCollectionEquality().hash(supportGoals),cardCharacter,guardianPin);

@override
String toString() {
  return 'OnboardingProfile(childNickname: $childNickname, supportGoals: $supportGoals, cardCharacter: $cardCharacter, guardianPin: $guardianPin)';
}


}

/// @nodoc
abstract mixin class $OnboardingProfileCopyWith<$Res>  {
  factory $OnboardingProfileCopyWith(OnboardingProfile value, $Res Function(OnboardingProfile) _then) = _$OnboardingProfileCopyWithImpl;
@useResult
$Res call({
 String childNickname, Set<SupportGoal> supportGoals, CardCharacter? cardCharacter, String guardianPin
});




}
/// @nodoc
class _$OnboardingProfileCopyWithImpl<$Res>
    implements $OnboardingProfileCopyWith<$Res> {
  _$OnboardingProfileCopyWithImpl(this._self, this._then);

  final OnboardingProfile _self;
  final $Res Function(OnboardingProfile) _then;

/// Create a copy of OnboardingProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? childNickname = null,Object? supportGoals = null,Object? cardCharacter = freezed,Object? guardianPin = null,}) {
  return _then(_self.copyWith(
childNickname: null == childNickname ? _self.childNickname : childNickname // ignore: cast_nullable_to_non_nullable
as String,supportGoals: null == supportGoals ? _self.supportGoals : supportGoals // ignore: cast_nullable_to_non_nullable
as Set<SupportGoal>,cardCharacter: freezed == cardCharacter ? _self.cardCharacter : cardCharacter // ignore: cast_nullable_to_non_nullable
as CardCharacter?,guardianPin: null == guardianPin ? _self.guardianPin : guardianPin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OnboardingProfile].
extension OnboardingProfilePatterns on OnboardingProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnboardingProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnboardingProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnboardingProfile value)  $default,){
final _that = this;
switch (_that) {
case _OnboardingProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnboardingProfile value)?  $default,){
final _that = this;
switch (_that) {
case _OnboardingProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String childNickname,  Set<SupportGoal> supportGoals,  CardCharacter? cardCharacter,  String guardianPin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnboardingProfile() when $default != null:
return $default(_that.childNickname,_that.supportGoals,_that.cardCharacter,_that.guardianPin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String childNickname,  Set<SupportGoal> supportGoals,  CardCharacter? cardCharacter,  String guardianPin)  $default,) {final _that = this;
switch (_that) {
case _OnboardingProfile():
return $default(_that.childNickname,_that.supportGoals,_that.cardCharacter,_that.guardianPin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String childNickname,  Set<SupportGoal> supportGoals,  CardCharacter? cardCharacter,  String guardianPin)?  $default,) {final _that = this;
switch (_that) {
case _OnboardingProfile() when $default != null:
return $default(_that.childNickname,_that.supportGoals,_that.cardCharacter,_that.guardianPin);case _:
  return null;

}
}

}

/// @nodoc


class _OnboardingProfile extends OnboardingProfile {
  const _OnboardingProfile({this.childNickname = '', final  Set<SupportGoal> supportGoals = const <SupportGoal>{}, this.cardCharacter, this.guardianPin = ''}): _supportGoals = supportGoals,super._();
  

/// 아이 호칭. 실명이 아니어도 된다고 온보딩에서 안내한다.
@override@JsonKey() final  String childNickname;
 final  Set<SupportGoal> _supportGoals;
@override@JsonKey() Set<SupportGoal> get supportGoals {
  if (_supportGoals is EqualUnmodifiableSetView) return _supportGoals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_supportGoals);
}

@override final  CardCharacter? cardCharacter;
/// 보호자 모드 전환용 4자리 PIN
@override@JsonKey() final  String guardianPin;

/// Create a copy of OnboardingProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnboardingProfileCopyWith<_OnboardingProfile> get copyWith => __$OnboardingProfileCopyWithImpl<_OnboardingProfile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnboardingProfile&&(identical(other.childNickname, childNickname) || other.childNickname == childNickname)&&const DeepCollectionEquality().equals(other._supportGoals, _supportGoals)&&(identical(other.cardCharacter, cardCharacter) || other.cardCharacter == cardCharacter)&&(identical(other.guardianPin, guardianPin) || other.guardianPin == guardianPin));
}


@override
int get hashCode => Object.hash(runtimeType,childNickname,const DeepCollectionEquality().hash(_supportGoals),cardCharacter,guardianPin);

@override
String toString() {
  return 'OnboardingProfile(childNickname: $childNickname, supportGoals: $supportGoals, cardCharacter: $cardCharacter, guardianPin: $guardianPin)';
}


}

/// @nodoc
abstract mixin class _$OnboardingProfileCopyWith<$Res> implements $OnboardingProfileCopyWith<$Res> {
  factory _$OnboardingProfileCopyWith(_OnboardingProfile value, $Res Function(_OnboardingProfile) _then) = __$OnboardingProfileCopyWithImpl;
@override @useResult
$Res call({
 String childNickname, Set<SupportGoal> supportGoals, CardCharacter? cardCharacter, String guardianPin
});




}
/// @nodoc
class __$OnboardingProfileCopyWithImpl<$Res>
    implements _$OnboardingProfileCopyWith<$Res> {
  __$OnboardingProfileCopyWithImpl(this._self, this._then);

  final _OnboardingProfile _self;
  final $Res Function(_OnboardingProfile) _then;

/// Create a copy of OnboardingProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? childNickname = null,Object? supportGoals = null,Object? cardCharacter = freezed,Object? guardianPin = null,}) {
  return _then(_OnboardingProfile(
childNickname: null == childNickname ? _self.childNickname : childNickname // ignore: cast_nullable_to_non_nullable
as String,supportGoals: null == supportGoals ? _self._supportGoals : supportGoals // ignore: cast_nullable_to_non_nullable
as Set<SupportGoal>,cardCharacter: freezed == cardCharacter ? _self.cardCharacter : cardCharacter // ignore: cast_nullable_to_non_nullable
as CardCharacter?,guardianPin: null == guardianPin ? _self.guardianPin : guardianPin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
