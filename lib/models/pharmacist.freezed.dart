// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pharmacist.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Pharmacist {

@JsonKey(name: 'pharmacist_id', includeIfNull: false) int? get id;@JsonKey(name: 'name', includeIfNull: false) String? get name;@JsonKey(name: 'dob', includeIfNull: false) String? get dob;@JsonKey(name: 'address', includeIfNull: false) String? get address;@JsonKey(name: 'phone', includeIfNull: false) String? get phone;@JsonKey(name: 'email', includeIfNull: false) String? get email;@JsonKey(name: 'accessToken', includeIfNull: false) String? get accessToken;@JsonKey(name: 'refreshToken', includeIfNull: false) String? get refreshToken;
/// Create a copy of Pharmacist
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PharmacistCopyWith<Pharmacist> get copyWith => _$PharmacistCopyWithImpl<Pharmacist>(this as Pharmacist, _$identity);

  /// Serializes this Pharmacist to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Pharmacist&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.dob, dob) || other.dob == dob)&&(identical(other.address, address) || other.address == address)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,dob,address,phone,email,accessToken,refreshToken);

@override
String toString() {
  return 'Pharmacist(id: $id, name: $name, dob: $dob, address: $address, phone: $phone, email: $email, accessToken: $accessToken, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class $PharmacistCopyWith<$Res>  {
  factory $PharmacistCopyWith(Pharmacist value, $Res Function(Pharmacist) _then) = _$PharmacistCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'pharmacist_id', includeIfNull: false) int? id,@JsonKey(name: 'name', includeIfNull: false) String? name,@JsonKey(name: 'dob', includeIfNull: false) String? dob,@JsonKey(name: 'address', includeIfNull: false) String? address,@JsonKey(name: 'phone', includeIfNull: false) String? phone,@JsonKey(name: 'email', includeIfNull: false) String? email,@JsonKey(name: 'accessToken', includeIfNull: false) String? accessToken,@JsonKey(name: 'refreshToken', includeIfNull: false) String? refreshToken
});




}
/// @nodoc
class _$PharmacistCopyWithImpl<$Res>
    implements $PharmacistCopyWith<$Res> {
  _$PharmacistCopyWithImpl(this._self, this._then);

  final Pharmacist _self;
  final $Res Function(Pharmacist) _then;

/// Create a copy of Pharmacist
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? name = freezed,Object? dob = freezed,Object? address = freezed,Object? phone = freezed,Object? email = freezed,Object? accessToken = freezed,Object? refreshToken = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,dob: freezed == dob ? _self.dob : dob // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,accessToken: freezed == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String?,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Pharmacist].
extension PharmacistPatterns on Pharmacist {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Pharmacist value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Pharmacist() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Pharmacist value)  $default,){
final _that = this;
switch (_that) {
case _Pharmacist():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Pharmacist value)?  $default,){
final _that = this;
switch (_that) {
case _Pharmacist() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'pharmacist_id', includeIfNull: false)  int? id, @JsonKey(name: 'name', includeIfNull: false)  String? name, @JsonKey(name: 'dob', includeIfNull: false)  String? dob, @JsonKey(name: 'address', includeIfNull: false)  String? address, @JsonKey(name: 'phone', includeIfNull: false)  String? phone, @JsonKey(name: 'email', includeIfNull: false)  String? email, @JsonKey(name: 'accessToken', includeIfNull: false)  String? accessToken, @JsonKey(name: 'refreshToken', includeIfNull: false)  String? refreshToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Pharmacist() when $default != null:
return $default(_that.id,_that.name,_that.dob,_that.address,_that.phone,_that.email,_that.accessToken,_that.refreshToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'pharmacist_id', includeIfNull: false)  int? id, @JsonKey(name: 'name', includeIfNull: false)  String? name, @JsonKey(name: 'dob', includeIfNull: false)  String? dob, @JsonKey(name: 'address', includeIfNull: false)  String? address, @JsonKey(name: 'phone', includeIfNull: false)  String? phone, @JsonKey(name: 'email', includeIfNull: false)  String? email, @JsonKey(name: 'accessToken', includeIfNull: false)  String? accessToken, @JsonKey(name: 'refreshToken', includeIfNull: false)  String? refreshToken)  $default,) {final _that = this;
switch (_that) {
case _Pharmacist():
return $default(_that.id,_that.name,_that.dob,_that.address,_that.phone,_that.email,_that.accessToken,_that.refreshToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'pharmacist_id', includeIfNull: false)  int? id, @JsonKey(name: 'name', includeIfNull: false)  String? name, @JsonKey(name: 'dob', includeIfNull: false)  String? dob, @JsonKey(name: 'address', includeIfNull: false)  String? address, @JsonKey(name: 'phone', includeIfNull: false)  String? phone, @JsonKey(name: 'email', includeIfNull: false)  String? email, @JsonKey(name: 'accessToken', includeIfNull: false)  String? accessToken, @JsonKey(name: 'refreshToken', includeIfNull: false)  String? refreshToken)?  $default,) {final _that = this;
switch (_that) {
case _Pharmacist() when $default != null:
return $default(_that.id,_that.name,_that.dob,_that.address,_that.phone,_that.email,_that.accessToken,_that.refreshToken);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _Pharmacist implements Pharmacist {
   _Pharmacist({@JsonKey(name: 'pharmacist_id', includeIfNull: false) this.id, @JsonKey(name: 'name', includeIfNull: false) this.name, @JsonKey(name: 'dob', includeIfNull: false) this.dob, @JsonKey(name: 'address', includeIfNull: false) this.address, @JsonKey(name: 'phone', includeIfNull: false) this.phone, @JsonKey(name: 'email', includeIfNull: false) this.email, @JsonKey(name: 'accessToken', includeIfNull: false) this.accessToken = 'no-accessToken-provided', @JsonKey(name: 'refreshToken', includeIfNull: false) this.refreshToken = 'no-refreshToken-provided'});
  factory _Pharmacist.fromJson(Map<String, dynamic> json) => _$PharmacistFromJson(json);

@override@JsonKey(name: 'pharmacist_id', includeIfNull: false) final  int? id;
@override@JsonKey(name: 'name', includeIfNull: false) final  String? name;
@override@JsonKey(name: 'dob', includeIfNull: false) final  String? dob;
@override@JsonKey(name: 'address', includeIfNull: false) final  String? address;
@override@JsonKey(name: 'phone', includeIfNull: false) final  String? phone;
@override@JsonKey(name: 'email', includeIfNull: false) final  String? email;
@override@JsonKey(name: 'accessToken', includeIfNull: false) final  String? accessToken;
@override@JsonKey(name: 'refreshToken', includeIfNull: false) final  String? refreshToken;

/// Create a copy of Pharmacist
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PharmacistCopyWith<_Pharmacist> get copyWith => __$PharmacistCopyWithImpl<_Pharmacist>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PharmacistToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Pharmacist&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.dob, dob) || other.dob == dob)&&(identical(other.address, address) || other.address == address)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,dob,address,phone,email,accessToken,refreshToken);

@override
String toString() {
  return 'Pharmacist(id: $id, name: $name, dob: $dob, address: $address, phone: $phone, email: $email, accessToken: $accessToken, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class _$PharmacistCopyWith<$Res> implements $PharmacistCopyWith<$Res> {
  factory _$PharmacistCopyWith(_Pharmacist value, $Res Function(_Pharmacist) _then) = __$PharmacistCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'pharmacist_id', includeIfNull: false) int? id,@JsonKey(name: 'name', includeIfNull: false) String? name,@JsonKey(name: 'dob', includeIfNull: false) String? dob,@JsonKey(name: 'address', includeIfNull: false) String? address,@JsonKey(name: 'phone', includeIfNull: false) String? phone,@JsonKey(name: 'email', includeIfNull: false) String? email,@JsonKey(name: 'accessToken', includeIfNull: false) String? accessToken,@JsonKey(name: 'refreshToken', includeIfNull: false) String? refreshToken
});




}
/// @nodoc
class __$PharmacistCopyWithImpl<$Res>
    implements _$PharmacistCopyWith<$Res> {
  __$PharmacistCopyWithImpl(this._self, this._then);

  final _Pharmacist _self;
  final $Res Function(_Pharmacist) _then;

/// Create a copy of Pharmacist
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? name = freezed,Object? dob = freezed,Object? address = freezed,Object? phone = freezed,Object? email = freezed,Object? accessToken = freezed,Object? refreshToken = freezed,}) {
  return _then(_Pharmacist(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,dob: freezed == dob ? _self.dob : dob // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,accessToken: freezed == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String?,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
