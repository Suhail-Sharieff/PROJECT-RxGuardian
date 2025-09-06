import 'dart:convert';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/enums.dart';
import '../models/pharmacist.dart';
import '../network/network_constants.dart';
import '../network/response_handler.dart';
import '../widgets/show_toast.dart';

class AuthController extends GetxController {
  static final instance = FirebaseAuth.instance;

  final Rx<Pharmacist?> user = Rx<Pharmacist?>(null);
  String? accessToken;
  Future<bool> verifyManagerAccess() async {
    // We test access by trying to fetch the first page of a known manager-only route.
    // A success (200) means access is granted. A failure (e.g., 403) means denied.
    var url = Uri.http(main_uri, '/manager');
    try {
      var res = await http.get(url, headers: {
        'authorization': 'Bearer $accessToken',
      });
      // If the server responds with OK, the user has manager access.
      return res.statusCode == 200;
    } catch (e) {
      // Any network error or failure to connect implies no access.
      print("Manager access check failed: $e");
      return false;
    }
  }
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String dob,
    required String address,
    required String phone,
    required BuildContext context,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        showToast(context, 'Enter proper email/password !', ToastType.WARNING);
        return false;
      }
    final userCredential=await instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if(!userCredential.user!.emailVerified) return false;

      var url = Uri.http(main_uri, '/auth/register');
      var res = await http.post(
        url,
        body: {'name':name,'dob':dob,'address':address,'phone':phone,'password':password,'email':email},
        headers: {'authorization': 'Bearer $accessToken'},
      );
      if(ResponseHandler.is_good_response(res, context)){
        return true;
      }
      return false;
    } catch (e) {
      showToast(context, e.toString(), ToastType.ERROR);
    }
    return false;
  }

  Future<SignedUpUserStatus> signIn({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      // --- STEP 1: Authenticate with Firebase ---
      log("Signing in with Firebase...");
      final userCredential = await instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        return SignedUpUserStatus.INVALID;
      }

      // --- STEP 2: Check for email verification ---
      if (!userCredential.user!.emailVerified) {
        log("Email not verified for ${userCredential.user!.email}");
        showToast(context, "Please verify your email before logging in.", ToastType.WARNING);
        return SignedUpUserStatus.IS_NOT_EMAIL_VERFIED;
      }
      log("Firebase sign-in successful and email is verified.");

      // --- STEP 3: Authenticate with your backend ---
      log("Signing in with backend server...");
      var url = Uri.http(main_uri, '/auth/login');
      var res = await http.post(
        url,
        body: {"password": password, "email": email}, // Or send Firebase ID token
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) { // Check for a successful status code
        log("Backend login failed with status: ${res.statusCode}");
        showToast(context, "Backend authentication failed.", ToastType.ERROR);
        return SignedUpUserStatus.INVALID;
      }

      // --- STEP 4: Process backend response and update state ---
      var responseData = jsonDecode(res.body)['data'];
      var pharmacistJson = responseData['pharmacist'];

      final newAccessToken = responseData['accessToken'];
      final newRefreshToken = responseData['refreshToken'];

      final loggedInUser = Pharmacist.fromJson(pharmacistJson);
      // log(loggedInUser.toString());
      this.user.value = loggedInUser;
      this.accessToken = newAccessToken;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refreshToken', newRefreshToken);

      log('Backend login successful. User state updated.');
      return SignedUpUserStatus.IS_EMAIL_VERFIED;

    } on FirebaseAuthException catch (e) {
      log("Firebase sign-in error: ${e.code}");
      showToast(context, e.message ?? "Invalid credentials.", ToastType.ERROR);
      return SignedUpUserStatus.INVALID;
    } on Exception catch(e) {
      log("A general exception occurred during sign-in: $e");
      showToast(context, "An error occurred. Please try again.", ToastType.ERROR);
      return SignedUpUserStatus.INVALID;
    }
  }

  static Future<void> sendVerifyLink({required BuildContext context}) async {
    try {
      await instance.currentUser?.sendEmailVerification();
    } catch (e) {
      showToast(
        context,
        "Some error occurred in sending mail!",
        ToastType.ERROR,
      );
    }
  }

  //------------to maintain conn with server even on refresh -----VVVIMP
  Future<bool> tryToRestoreSession(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRefreshToken = prefs.getString('refreshToken');

      // If no token is found, there's no session to restore.
      if (savedRefreshToken == null || savedRefreshToken.isEmpty) {
        log("No refresh token found. User is not logged in.");
        return false;
      }

      log("Found refresh token. Attempting to restore session...");

      // --- Call your NEW backend endpoint for refreshing the token ---
      var url = Uri.http(main_uri, '/auth/refresh-token'); // IMPORTANT: This endpoint must exist!
      var res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $savedRefreshToken', // Send token in header
        },
      ).timeout(const Duration(seconds: 10));

      // If the token is expired or invalid, the backend should return 401 or 403
      if (res.statusCode != 200) {
        log("Session restoration failed. Refresh token is invalid or expired. Status: ${res.statusCode}");
        // It's good practice to log the user out to clear the invalid token
        await logout(context: context);
        return false;
      }

      // --- Process the successful response ---
      var responseData = jsonDecode(res.body)['data'];
      var pharmacistJson = responseData['pharmacist'];
      final newAccessToken = responseData['accessToken']; // Backend must return a new access token

      if (pharmacistJson == null || newAccessToken == null) {
        log("Session restoration failed: Invalid data from backend.");
        return false;
      }

      // --- Update the application state with the restored session data ---
      final loggedInUser = Pharmacist.fromJson(pharmacistJson);
      this.user.value = loggedInUser;
      this.accessToken = newAccessToken;

      log('Session restored successfully for ${loggedInUser.name}');
      return true;

    } on Exception catch (e) {
      log("An exception occurred during session restoration: $e");
      return false;
    }
  }

  Future<void> logout({required BuildContext context}) async {
    try {
      await instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('refreshToken');
      var url=Uri.http(main_uri,'/auth/logout');
      // log('logout out using ref token: $my_ref_token');
      var res=await http.post(url,headers:
      {
        'authorization': 'Bearer $accessToken'
      });
      if(!ResponseHandler.is_good_response(res, context)){
        showToast(context, "Server failed to logout! Pls login again", ToastType.ERROR);
      }
      user.value=null;
      accessToken=null;
      showToast(context, "Logout success", ToastType.SUCCESS);
    } catch (e) {
      showToast(
        context,
        "Some error occurred in logging out!",
        ToastType.ERROR,
      );
    }
  }
  Future<void> updatePassword({required BuildContext context,required String oldPassword,required String newPassword})async{
    try{
      await instance.sendPasswordResetEmail(email: user.value!.email!);
    }catch(e){
      showToast(context, "Failed to update password", ToastType.ERROR);
    }
  }
  Future<Map<String,dynamic>> getCurrPharmacistProfile(BuildContext con)async{
    try{
      var url=Uri.http(main_uri,'/auth/getCurrPharmacistProfile');
      var res=await http.get(url,headers:
      {
        'authorization': 'Bearer $accessToken'
      });
  log(res.body.toString());
      return jsonDecode(res.body)['data'];
    }catch(err){
      throw Exception("Failed to fetch !${err.toString()}");
    }
  }

  Future<Map<String,dynamic>>getMyShopAnalysis(BuildContext context,int pgNumber)async{
    try{
      var url=Uri.http(main_uri,'/shop/getMyShopAnalysis',{'pgNo': pgNumber.toString()});
      var res=await http.get(url,headers:
      {
        'authorization': 'Bearer $accessToken'
      });
      log(res.body.toString());
      return jsonDecode(res.body)['data'];
    }catch(err){
      throw Exception("Failed to fetch !${err.toString()}");
    }
  }

}
