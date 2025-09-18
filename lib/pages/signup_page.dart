import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rxGuardian/pages/verify_email_page.dart';

import '../constants/RxGuardianLogo.dart';
import '../constants/colors.dart';
import '../constants/routes.dart';
import '../controllers/auth_controller.dart';
import '../widgets/show_toast.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  static String route_name = signup_route;
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // --- CONTROLLERS ---
  final _nameController = TextEditingController();
  final _dobController = TextEditingController(); // For Date of Birth
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  final AuthController contr = Get.find();

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
          'Create your account to start managing your pharmacy with ease!',
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
        // Name Field
        TextFormField(
          controller: _nameController,
          keyboardType: TextInputType.name,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: _buildInputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icons.person_outline,
          ),
        ),
        const SizedBox(height: 20),

        // Date of Birth Field
        TextFormField(
          controller: _dobController,
          readOnly: true, // Prevents keyboard from appearing
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: _buildInputDecoration(
            labelText: 'Date of Birth',
            prefixIcon: Icons.calendar_today_outlined,
          ),
          onTap: () async {
            // Show date picker when the field is tapped
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
            );
            if (pickedDate != null) {
              // Format the date and set it to the controller
              String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
              setState(() {
                _dobController.text = formattedDate;
              });
            }
          },
        ),
        const SizedBox(height: 20),

        // Address Field
        TextFormField(
          controller: _addressController,
          keyboardType: TextInputType.streetAddress,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: _buildInputDecoration(
            labelText: 'Address',
            prefixIcon: Icons.home_outlined,
          ),
        ),
        const SizedBox(height: 20),

        // Phone Field
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: _buildInputDecoration(
            labelText: 'Phone Number',
            prefixIcon: Icons.phone_outlined,
          ),
        ),
        const SizedBox(height: 20),

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
        const SizedBox(height: 20),

        // Confirm Password Field
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: !_confirmPasswordVisible,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: _buildInputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _confirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: kSecondaryTextColor,
              ),
              onPressed: () {
                setState(() => _confirmPasswordVisible = !_confirmPasswordVisible);
              },
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Sign Up Button
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
            if (_passwordController.text != _confirmPasswordController.text) {
              showToast(context, "Passwords do not match!", ToastType.WARNING);
              return;
            }
            // Pass all the new data to the signUp method
            if (await contr.signUp(
              name: _nameController.text,
              dob: _dobController.text,
              address: _addressController.text,
              phone: _phoneController.text,
              email: _emailController.text,
              password: _passwordController.text,
              context: context,
            )) {
              if (mounted) {
                Navigator.of(context).pushNamed(VerifyEmailPage.route_name);
              }
            }
            showToast(context, "Please Login now", ToastType.SUCCESS);
            Navigator.of(context).pushReplacementNamed(LoginPage.route_name);
          },
          child: Text(
            'Create Account',
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
          "Already have an account?",
          style: GoogleFonts.poppins(color: kSecondaryTextColor),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(LoginPage.route_name);
          },
          child: Text(
            'Login',
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
