import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import '../network/network_constants.dart';

// --- DATA MODEL ---
class PharmacistEmployee {
  final int pharmacistId;
  final String pharmacistName;
  final String pharmacistAddress;
  final String pharmacistPhone;
  final String pharmacistEmail;
  final num pharmacistSalary;
  final String role;
  final int nSalesMade;

  PharmacistEmployee({
    required this.pharmacistId,
    required this.pharmacistName,
    required this.pharmacistAddress,
    required this.pharmacistPhone,
    required this.pharmacistEmail,
    required this.pharmacistSalary,
    required this.role,
    required this.nSalesMade,
  });

  // A method to create a copy with a new salary
  PharmacistEmployee copyWith({num? newSalary}) {
    return PharmacistEmployee(
      pharmacistId: pharmacistId,
      pharmacistName: pharmacistName,
      pharmacistAddress: pharmacistAddress,
      pharmacistPhone: pharmacistPhone,
      pharmacistEmail: pharmacistEmail,
      pharmacistSalary: newSalary ?? pharmacistSalary,
      role: role,
      nSalesMade: nSalesMade,
    );
  }

  factory PharmacistEmployee.fromJson(Map<String, dynamic> json) {
    return PharmacistEmployee(
      pharmacistId: json['pharmacist_id'],
      pharmacistName: json['pharmacist_name'],
      pharmacistAddress: json['pharmacist_address'],
      pharmacistPhone: json['pharmacist_phone'],
      pharmacistEmail: json['pharmacist_email'],
      pharmacistSalary: json['pharmacist_salary'],
      role: json['Role'],
      nSalesMade: json['nSalesMade'],
    );
  }
}

// --- DATA CONTROLLER (Handles API Logic) ---
class EmployeeDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<List<dynamic>> getEmployeeDetails(
      Map<String, String> queryParams) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/manager/getEmployeeDetails', queryParams);

    try {
      var res = await http.get(url, headers: {
        'authorization': 'Bearer $accessToken',
      });

      // print(jsonDecode(res.body.toString()));

      if (res.statusCode == 200) {
        final decodedBody = jsonDecode(res.body);
        return decodedBody['data'];
      } else {
        final errorBody = jsonDecode(res.body);
        throw Exception(
            'Failed to load data: ${errorBody['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }

  // ADDED: API call to update salary
  Future<void> updateEmployeeSalary(int pharmacistId, num newSalary) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/manager/updateEmployeeSalary');
    try {
      var res = await http.patch(
        url,
        headers: {
          'authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pharmacist_id': pharmacistId, 'newSalary': newSalary}),
      );
      if (res.statusCode != 200) {
        final errorBody = jsonDecode(res.body);
        throw Exception(
            'Failed to update salary: ${errorBody['message'] ?? 'Server error'}');
      }
    } catch (e) {
      throw Exception('An error occurred while updating salary: ${e.toString()}');
    }
  }

  // ADDED: API call to remove an employee
  Future<void> removeEmployee(int pharmacistId) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/manager/removeEmployee/$pharmacistId');
    try {
      var res = await http.delete(
        url,
        headers: {'authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode != 200) {
        final errorBody = jsonDecode(res.body);
        throw Exception(
            'Failed to remove employee: ${errorBody['message'] ?? 'Server error'}');
      }
    } catch (e) {
      throw Exception('An error occurred while removing employee: ${e.toString()}');
    }
  }
}

// --- UI STATE CONTROLLER ---
class EmployeeUIController extends GetxController {
  var isLoading = true.obs;
  var isLoadingMore = false.obs;
  var employeeList = <PharmacistEmployee>[].obs;

  final EmployeeDataController _dataController = Get.put(EmployeeDataController());

  var pageNumber = 1;
  var hasMoreData = true;
  final scrollController = ScrollController();
  final nameSearchController = TextEditingController();
  final idSearchController = TextEditingController();
  final emailSearchController = TextEditingController();
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    fetchEmployeeData();
    scrollController.addListener(() {
      if (scrollController.position.maxScrollExtent == scrollController.offset) {
        fetchEmployeeData();
      }
    });
    nameSearchController.addListener(_onSearchChanged);
    idSearchController.addListener(_onSearchChanged);
    emailSearchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    scrollController.dispose();
    nameSearchController.dispose();
    idSearchController.dispose();
    emailSearchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> fetchEmployeeData({bool isSearch = false}) async {
    if (isLoadingMore.value || (!hasMoreData && !isSearch)) return;

    if (isSearch) {
      pageNumber = 1;
      hasMoreData = true;
      employeeList.clear();
      isLoading(true);
    } else {
      isLoadingMore(true);
    }

    try {
      final queryParams = {
        'pgNo': pageNumber.toString(),
        if (nameSearchController.text.isNotEmpty)
          'searchPharmacistByName': nameSearchController.text,
        if (idSearchController.text.isNotEmpty)
          'searchPharmacistById': idSearchController.text,
        if (emailSearchController.text.isNotEmpty)
          'searchPharmacistByEmail': emailSearchController.text,
      };

      final List<dynamic> data =
      await _dataController.getEmployeeDetails(queryParams);
      final newData =
      data.map((item) => PharmacistEmployee.fromJson(item)).toList();

      if (newData.isEmpty) {
        hasMoreData = false;
        if (pageNumber > 1) {
          Get.snackbar(
            "Notice",
            "You've reached the end of the list.",
            backgroundColor: kWarningColor,
            colorText: Colors.white,
          );
        }
      } else {
        employeeList.addAll(newData);
        pageNumber++;
      }
    } catch (err) {
      Get.snackbar(
        'Error',
        err.toString().replaceAll('Exception: ', ''),
        backgroundColor: kErrorColor,
        colorText: Colors.white,
      );
      hasMoreData = false;
    } finally {
      isLoading(false);
      isLoadingMore(false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      fetchEmployeeData(isSearch: true);
    });
  }

  Future<void> handleUpdateSalary(int pharmacistId, num newSalary) async {
    try {
      await _dataController.updateEmployeeSalary(pharmacistId, newSalary);
      int index = employeeList.indexWhere((e) => e.pharmacistId == pharmacistId);
      if (index != -1) {
        employeeList[index] = employeeList[index].copyWith(newSalary: newSalary);
      }
      Get.snackbar(
        'Success',
        "Salary updated successfully!",
        backgroundColor: kPrimaryColor,
        colorText: Colors.white,
      );
    } catch (err) {
      Get.snackbar(
        'Error',
        err.toString().replaceAll('Exception: ', ''),
        backgroundColor: kErrorColor,
        colorText: Colors.white,
      );
    }
  }

  Future<void> handleRemoveEmployee(int pharmacistId) async {
    try {
      await _dataController.removeEmployee(pharmacistId);
      employeeList.removeWhere((e) => e.pharmacistId == pharmacistId);
      Get.snackbar(
        'Success',
        "Employee removed successfully!",
        backgroundColor: kPrimaryColor,
        colorText: Colors.white,
      );
    } catch (err) {
      Get.snackbar(
        'Error',
        err.toString().replaceAll('Exception: ', ''),
        backgroundColor: kErrorColor,
        colorText: Colors.white,
      );
    }
  }
}

// --- UI WIDGET ---
class EmployeeDetailPage extends StatelessWidget {
  const EmployeeDetailPage({super.key});
  static const route_name = employee_details_route;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EmployeeUIController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Employee Details', style: theme.textTheme.titleLarge),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(180.0),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                _SearchTextField(
                  controller: controller.nameSearchController,
                  hintText: 'Search by Name...',
                  icon: Icons.person_search_outlined,
                ),
                const SizedBox(height: 8),
                _SearchTextField(
                  controller: controller.idSearchController,
                  hintText: 'Search by ID...',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 8),
                _SearchTextField(
                  controller: controller.emailSearchController,
                  hintText: 'Search by Email...',
                  icon: Icons.alternate_email_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: kPrimaryColor));
        }
        if (controller.employeeList.isEmpty) {
          return Center(
              child: Text("No employee data found.",
                  style: TextStyle(color: theme.hintColor)));
        }
        return ListView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.all(16.0),
          itemCount: controller.employeeList.length +
              (controller.isLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == controller.employeeList.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                    child: CircularProgressIndicator(color: kPrimaryColor)),
              );
            }
            final item = controller.employeeList[index];
            return _EmployeeCard(employee: item);
          },
        );
      }),
    );
  }
}

class _SearchTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  const _SearchTextField(
      {required this.controller, required this.hintText, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.hintColor),
        prefixIcon: Icon(icon, color: theme.hintColor, size: 20),
        filled: true,
        fillColor: theme.dividerColor.withOpacity(0.1),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final PharmacistEmployee employee;
  const _EmployeeCard({required this.employee});

  Color _getRoleColor(String role) {
    return role.toLowerCase() == 'manager' ? kPrimaryColor : Colors.blueGrey;
  }

  void _showEditSalaryDialog(BuildContext context, EmployeeUIController controller) {
    final salaryController =
    TextEditingController(text: employee.pharmacistSalary.toString());
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('Update Salary', style: theme.textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editing salary for ${employee.pharmacistName}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                controller: salaryController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: 'New Salary',
                  labelStyle: TextStyle(color: theme.hintColor),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newSalary = num.tryParse(salaryController.text);
                if (newSalary != null) {
                  await controller.handleUpdateSalary(employee.pharmacistId, newSalary);
                  if (context.mounted) Navigator.of(context).pop();
                } else {
                  Get.snackbar(
                    'Warning',
                    'Please enter a valid number.',
                    backgroundColor: kWarningColor,
                    colorText: Colors.white,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmRemoveDialog(BuildContext context, EmployeeUIController controller) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('Confirm Removal', style: theme.textTheme.titleLarge),
          content: Text(
              'Are you sure you want to remove ${employee.pharmacistName} from the shop?',
              style: theme.textTheme.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
              onPressed: () async {
                await controller.handleRemoveEmployee(employee.pharmacistId);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<EmployeeUIController>();
    final authController = Get.find<AuthController>();
    final isSelf = authController.user.value?.id == employee.pharmacistId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _getRoleColor(employee.role).withOpacity(0.1),
                child: Icon(Icons.person_outline,
                    color: _getRoleColor(employee.role)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.pharmacistName,
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleMedium?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Pharmacist ID: ${employee.pharmacistId}',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSelf)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditSalaryDialog(context, controller);
                    } else if (value == 'remove') {
                      _showConfirmRemoveDialog(context, controller);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Salary'),
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'remove',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: kErrorColor),
                        title: Text('Remove Employee', style: TextStyle(color: kErrorColor)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Divider(color: theme.dividerColor, height: 24),
          _InfoRow(
            icon: Icons.email_outlined,
            text: employee.pharmacistEmail,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.phone_outlined,
            text: employee.pharmacistPhone,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: employee.pharmacistAddress,
          ),
          Divider(color: theme.dividerColor, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                  label: 'Salary',
                  value: '₹${employee.pharmacistSalary}',
                  icon: Icons.wallet_outlined),
              _StatItem(
                  label: 'Sales Made',
                  value: employee.nSalesMade.toString(),
                  icon: Icons.trending_up),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.iconTheme.color?.withOpacity(0.7), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.iconTheme.color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

