
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxGuardian/pages/signup_page.dart';
import 'package:rxGuardian/pages/verify_email_page.dart';
import '../constants/RxGuardianLogo.dart';
import '../constants/enums.dart';
import '../constants/routes.dart';
import '../services/auth/auth_methods.dart';

import '../constants/colors.dart';
import 'forgot_password_page.dart';
import 'landing_page.dart';

class LoginPage extends StatefulWidget {
  static String route_name = login_route; // Your route name
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildForm(),
                  const SizedBox(height: 24),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- HEADER WIDGET ---
  Widget _buildHeader() {
    return Column(
      children: [
        const RxGuadianLogo(size: 80),
        const SizedBox(height: 20),
        Text(
          'RxGuardian',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue your pharmacy management journey.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: kSecondaryTextColor,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // --- FORM WIDGET ---
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email Field
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: _buildInputDecoration(
            labelText: 'Email',
            prefixIcon: Icons.email_outlined,
          ),
        ),
        const SizedBox(height: 20),
        // Password Field
        TextFormField(
          controller: _passwordController,
          obscureText: !_passwordVisible,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: _buildInputDecoration(
            labelText: 'Password',
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: kSecondaryTextColor,
              ),
              onPressed: () {
                setState(() => _passwordVisible = !_passwordVisible);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              // Navigate to Forgot Password page
              Navigator.of(context).pushNamed(ForgotPassWordPage.route_name);
            },
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.poppins(
                color: kPrimaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Sign In Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: kPrimaryColor,
            foregroundColor: kBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            SignedUpUserStatus st = await AuthMethods.signIn(
                email: _emailController.text,
                password: _passwordController.text, context: context);
            if (st == SignedUpUserStatus.IS_EMAIL_VERFIED) {
              if(mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(LandingPage.route_name,(_)=>false);
              }
            } else if (st ==
                SignedUpUserStatus.IS_NOT_EMAIL_VERFIED) {
              if(mounted) {
                Navigator.of(context)
                    .pushNamed(VerifyEmailPage.route_name);
              }
            }
          },
          child: Text(
            'Sign In',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // --- FOOTER WIDGET ---
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: GoogleFonts.poppins(color: kSecondaryTextColor),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context)
                .pushReplacementNamed(SignupPage.route_name);
          },
          child: Text(
            'Sign Up',
            style: GoogleFonts.poppins(
              color: kPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPER for InputDecoration ---
  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.poppins(color: kSecondaryTextColor),
      prefixIcon: Icon(prefixIcon, color: kSecondaryTextColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: kCardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kInputBorderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kInputBorderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryColor, width: 2),
      ),
    );
  }
}


// --- CUSTOM LOGO WIDGET ---
