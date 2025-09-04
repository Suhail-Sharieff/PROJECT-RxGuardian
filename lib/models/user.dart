
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart'; // Ensure JSON serialization works
//flutter packages pub run build_runner build
@freezed
abstract class User  with _$User{
  @JsonSerializable(explicitToJson: true)
  factory User(
      {
        @JsonKey(name: 'user_id', includeIfNull: false) String? id,
        @Default('no-accessToken-provided')@JsonKey(name:'accessToken', includeIfNull: false) String? accessToken,
        @Default('no-refreshToken-provided')@JsonKey(name:'refreshToken', includeIfNull: false) String? refreshToken,
      }
      )=_User;
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}