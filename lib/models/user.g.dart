// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['user_id'] as String?,
  accessToken: json['accessToken'] as String? ?? 'no-accessToken-provided',
  refreshToken: json['refreshToken'] as String? ?? 'no-refreshToken-provided',
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  if (instance.id case final value?) 'user_id': value,
  if (instance.accessToken case final value?) 'accessToken': value,
  if (instance.refreshToken case final value?) 'refreshToken': value,
};
