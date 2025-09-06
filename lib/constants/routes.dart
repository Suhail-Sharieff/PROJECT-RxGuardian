
import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:rxGuardian/widgets/pharmacist_profile.dart';

import '../pages/drug_stock_details.dart';
import '../pages/forgot_password_page.dart';
import '../pages/home_page.dart';
import '../pages/landing_page.dart';
import '../pages/login_page.dart';
import '../pages/manager_console.dart';
import '../pages/signup_page.dart';
import '../pages/verify_email_page.dart';
import '../pages/employee_details.dart';
import '../widgets/pharmacy_purchase_analysis.dart';

const landing_route='/landing/';
const login_route='/login';
const forgot_password_route='/forgotPassword';
const signup_route='/signup/';
const verify_email_route='/verifyEmail/';
const home_route='/home/';
const profile_route='/profile/';
const shop_purchase_analysis_route='/shopAnalysis/';
const drug_stock_details_route='/drugStockDetails/';
const manager_console_route='/managerConsole/';
const employee_details_route='/employeeDetails/';





class AppPages {
  static final List<GetPage> pages = [
    GetPage(name: home_route, page: () => const HomePage(),),
    GetPage(name: landing_route, page: () => const LandingPage(),),
    GetPage(name: login_route,page: () => const LoginPage(),),
    GetPage(name: signup_route,page: () => const SignupPage(),),
    GetPage(name: verify_email_route,page: () => const VerifyEmailPage(),),
    GetPage(name: forgot_password_route, page: ()=>const ForgotPassWordPage()),
    GetPage(name: profile_route, page: ()=>const PharmacistProfileScreen()),
    GetPage(name: shop_purchase_analysis_route, page: ()=>const ShopPurchaseAnalysisPage()),
    GetPage(name: drug_stock_details_route, page: ()=>const PharmacyDrugStockDetailsPage()),
    GetPage(name: employee_details_route, page: ()=>const EmployeeDetailPage()),
    GetPage(name: manager_console_route, page: ()=>const ManagerConsolePage()),
  ];
}