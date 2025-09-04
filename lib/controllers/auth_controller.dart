import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/user.dart';
import '../network/http_exception_handler.dart';
import '../network/network_constants.dart';
import '../network/response_handler.dart';

class AuthController extends GetxController{

  final Rx<User?> user = Rx<User?>(null);
  String? accessToken;

  /// Logs in the user with their email and password.
  Future<User?> loginWithEmailAndPassword(
      String? email,
      String? password,
      BuildContext context,
      ) async {
    try {
      var url = Uri.http(main_uri, '/api/users/login'); // Replace with your main_uri
      var res = await http.post(
        url,
        body: {"password": password, "email": email},
      ).timeout(const Duration(seconds: 10));

      // Assuming ResponseHandler checks for res.statusCode == 200
      if (res.statusCode != 200) {
        // Handle non-200 responses appropriately
        log('Login failed with status: ${res.statusCode}');
        return null;
      }

      // 1. Decode the entire response and get the 'data' object.
      var responseData = jsonDecode(res.body)['data'];

      // 2. The user object is under the key 'pharmacist', not 'user'.
      var pharmacistJson = responseData['pharmacist'];
      if (pharmacistJson == null) {
        log('Error: Pharmacist data is null in the response.');
        return null;
      }

      // 3. The access and refresh tokens are directly inside 'data'.
      final newAccessToken = responseData['accessToken'];
      final newRefreshToken = responseData['refreshToken'];

      // 4. Create the User object from the 'pharmacist' JSON.
      final loggedInUser = User.fromJson(pharmacistJson);
      log('Logged in user: ${loggedInUser.toString()}');

      // 5. Update the controller's state.
      // Use .value to update an Rx variable.
      this.user.value = loggedInUser;
      this.accessToken = newAccessToken; // Store accessToken for the session

      // 6. Save the refresh token for long-term persistence.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refreshToken', newRefreshToken);

      log('Login successful. Refresh token saved.');

      return loggedInUser;

    } on Exception catch (e) {
      // Assuming HttpExceptionHandler is a custom class to show alerts/snackbars
      log('An exception occurred: $e');
      // HttpExceptionHandler.handle(e, context);
    }
    return null;
  }

  /// Checks if a refresh token exists in persistent storage.
  Future<bool> isLoggedIn(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('refreshToken');
    } on Exception catch (e) {
      log('An exception occurred: $e');
      // HttpExceptionHandler.handle(e, context);
    }
    return false;
  }


  Future<bool> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('refreshToken');
      var url=Uri.http(main_uri,'/api/users/logout');
      // log('logout out using ref token: $my_ref_token');
      var res=await http.post(url,headers:
      {
        'authorization': 'Bearer $my_ref_token'
      });
      if(ResponseHandler.is_good_response(res, context)){
        return true;
      }

    } on Exception catch (e) {
      HttpExceptionHandler.handle(Exception("Cant logout!"), context);
    }
    return false;
  }


  Future<bool>updatePassword(BuildContext context,String oldPassword,String newPassword) async {
    try {
      var url=Uri.http(main_uri,'/api/users/updatePassword');
      // log('logout out using ref token: $my_ref_token');
      var res=await http.post(url,
          body: {
            'oldPassword':oldPassword,
            'newPassword':newPassword,
          },
          headers:
          {
            'authorization': 'Bearer $my_ref_token'
          });

      if(ResponseHandler.is_good_response(res, context)){
        return true;
      }
    } on Exception catch (e) {
      HttpExceptionHandler.handle(e, context );
    }
    return false;
  }




  Future<bool> registerUser(BuildContext context,
      String? email,
      String? password,) async {
    try {
      var uri = Uri.http(main_uri, '/api/users/register');
      final request = http.MultipartRequest('POST', uri);

      request.fields['email'] = email ?? '';
      request.fields['userName'] = userName ?? '';
      request.fields['password'] = password ?? '';
      request.fields['fullName'] = fullName ?? '';

      if (profileImage != null && profileImage.path.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            profileImage.path,
            contentType: MediaType('image', 'jpeg'), // or 'png' if applicable
          ),
        );
      }

// Cover Image
      if (coverImage != null && coverImage.path.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'coverImage',
            coverImage.path,
            contentType: MediaType('image', 'jpeg'), // or 'png' if applicable
          ),
        );
      }

      final response = await request.send().timeout(
          const Duration(seconds: 10));

      if (response.statusCode == 200) {
        log('User registered successfully');
        return true;
      } else {
        HttpExceptionHandler.handle(Exception("Registration failed"), context);
      }
    } on Exception catch (e) {
      HttpExceptionHandler.handle(e, context);
    }
    return false;
  }
}