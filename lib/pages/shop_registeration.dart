import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import '../network/network_constants.dart';

// --- DATA CONTROLLER (API Logic) ---
class ShopDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<void> registerShop(Map<String, String> shopDetails) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/shop/registerShop');
    try {
      // log(url.toString());

      var res = await http.put(
        url,
        headers: {
          'authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(shopDetails),
      );
      final decodedBody = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(decodedBody['message'] ?? 'Failed to register shop');
      }
    } catch (e) {
      log(e.toString());
      throw Exception('An error occurred: ${e.toString()}');
    }
  }
}

// --- UI STATE CONTROLLER ---
class ShopRegistrationController extends GetxController {
  final ShopDataController _dataController = Get.put(ShopDataController());

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final licenseController = TextEditingController();

  var isLoading = false.obs;

  @override
  void onClose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    licenseController.dispose();
    super.onClose();
  }

  Future<void> submitRegistration() async {
    if (formKey.currentState?.validate() ?? false) {
      isLoading.value = true;
      try {
        final shopDetails = {
          'name': nameController.text,
          'address': addressController.text,
          'phone': phoneController.text,
          'license': licenseController.text,
        };
        await _dataController.registerShop(shopDetails);
        Get.snackbar('Success', 'Shop registered successfully!',
            backgroundColor: kPrimaryColor, colorText: Colors.white);
        // Optionally navigate to another page or clear form
        // Get.offAllNamed(ManagerConsolePage.route_name);
      } catch (e) {
        Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''),
            backgroundColor: kErrorColor, colorText: Colors.white);
      } finally {
        isLoading.value = false;
      }
    }
  }
}

// --- UI WIDGET ---
class ShopRegistrationPage extends StatelessWidget {
  const ShopRegistrationPage({super.key});
  static const route_name = shop_registration_route;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ShopRegistrationController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Register a New Shop', style: theme.textTheme.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Become a Manager',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill out the details below to register your pharmacy. You will automatically be assigned as the manager.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  _buildTextFormField(
                    controller: controller.nameController,
                    labelText: 'Shop Name',
                    icon: Icons.store_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: controller.addressController,
                    labelText: 'Shop Address',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: controller.phoneController,
                    labelText: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: controller.licenseController,
                    labelText: 'License Number',
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 32),
                  Obx(() => ElevatedButton.icon(
                    onPressed: controller.isLoading.value
                        ? null
                        : controller.submitRegistration,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    icon: controller.isLoading.value
                        ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.app_registration, size: 20),
                    label: Text(controller.isLoading.value
                        ? 'Registering...'
                        : 'Register Shop'),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field cannot be empty';
        }
        return null;
      },
    );
  }
}
