// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pharmacist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Pharmacist _$PharmacistFromJson(Map<String, dynamic> json) => _Pharmacist(
  id: (json['pharmacist_id'] as num?)?.toInt(),
  name: json['name'] as String?,
  dob: json['dob'] as String?,
  address: json['address'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  accessToken: json['accessToken'] as String? ?? 'no-accessToken-provided',
  refreshToken: json['refreshToken'] as String? ?? 'no-refreshToken-provided',
);

Map<String, dynamic> _$PharmacistToJson(_Pharmacist instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'pharmacist_id': value,
      if (instance.name case final value?) 'name': value,
      if (instance.dob case final value?) 'dob': value,
      if (instance.address case final value?) 'address': value,
      if (instance.phone case final value?) 'phone': value,
      if (instance.email case final value?) 'email': value,
      if (instance.accessToken case final value?) 'accessToken': value,
      if (instance.refreshToken case final value?) 'refreshToken': value,
    };
