
import 'package:flutter/cupertino.dart';

import '../pages/forgot_password_page.dart';
import '../pages/home_page.dart';
import '../pages/landing_page.dart';
import '../pages/login_page.dart';
import '../pages/signup_page.dart';
import '../pages/verify_email_page.dart';

const landing_route='/landing/';
const login_route='/login';
const forgot_password_route='/forgotPassword';
const signup_route='/signup/';
const verify_email_route='/verifyEmail/';
const home_route='/home/';





final Map<String, WidgetBuilder> routes = {
  LandingPage.route_name:(_)=>const LandingPage(),
  HomePage.route_name:(_)=>const HomePage(),
  LoginPage.route_name:(_)=>const LoginPage(),
  ForgotPassWordPage.route_name:(_)=>const ForgotPassWordPage(),
  SignupPage.route_name:(_)=>const SignupPage(),
  VerifyEmailPage.route_name:(_)=>const VerifyEmailPage(),
};