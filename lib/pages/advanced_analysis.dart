import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rxGuardian/constants/colors.dart';
import 'package:rxGuardian/constants/routes.dart';
import 'package:rxGuardian/controllers/auth_controller.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../network/network_constants.dart';

// --- ENUMS AND DATA MODELS ---
enum PerformanceFilterType { Day, Month, Year }

extension PerformanceFilterTypeExtension on PerformanceFilterType {
  String get titleName {
    switch (this) {
      case PerformanceFilterType.Day:
        return 'Daily';
      case PerformanceFilterType.Month:
        return 'Monthly';
      case PerformanceFilterType.Year:
        return 'Yearly';
    }
  }
}

class RevenueData {
  final dynamic xValue;
  final double netRevenue;
  RevenueData(this.xValue, this.netRevenue);
}

class SalesActivityData {
  final dynamic xValue;
  final int salesCount;
  final int customerCount;
  SalesActivityData(this.xValue, this.salesCount, this.customerCount);
}

// --- DATA CONTROLLER (API Logic) ---
class PerformanceDataController extends GetxController {
  final authController = Get.find<AuthController>();

  Future<List<dynamic>> getDateVsRevenue(Map<String, String> queryParams) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/sale/getDateVsRevenue', queryParams);
    try {
      var res = await http.get(url, headers: {'authorization': 'Bearer $accessToken'});
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['data'];
      } else {
        throw Exception('Failed to load revenue data: ${jsonDecode(res.body)['message']}');
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }

  Future<List<dynamic>> getDateVsSale(Map<String, String> queryParams) async {
    final accessToken = authController.accessToken;
    var url = Uri.http(main_uri, '/sale/getDateVsSale', queryParams);
    try {
      var res = await http.get(url, headers: {'authorization': 'Bearer $accessToken'});
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['data'];
      } else {
        throw Exception('Failed to load sales activity: ${jsonDecode(res.body)['message']}');
      }
    } catch (e) {
      throw Exception('An error occurred: ${e.toString()}');
    }
  }
}

// --- UI STATE CONTROLLER ---
class PerformanceUIController extends GetxController {
  final PerformanceDataController _dataController = Get.put(PerformanceDataController());

  var isLoading = true.obs;
  var selectedDate = DateTime.now().obs;
  var filterType = PerformanceFilterType.Day.obs;

  var revenueData = <RevenueData>[].obs;
  var salesActivityData = <SalesActivityData>[].obs;

  double get totalRevenue => revenueData.fold(0.0, (sum, item) => sum + item.netRevenue);
  int get totalSales => salesActivityData.fold(0, (sum, item) => sum + item.salesCount);

  @override
  void onInit() {
    super.onInit();
    fetchPerformanceData();
  }

  Future<void> fetchPerformanceData() async {
    isLoading.value = true;
    try {
      final queryParams = <String, String>{};
      if (filterType.value == PerformanceFilterType.Day) {
        queryParams['day'] = selectedDate.value.day.toString();
        queryParams['month'] = selectedDate.value.month.toString();
        queryParams['year'] = selectedDate.value.year.toString();
      } else if (filterType.value == PerformanceFilterType.Month) {
        queryParams['month'] = selectedDate.value.month.toString();
        queryParams['year'] = selectedDate.value.year.toString();
      } else {
        queryParams['year'] = selectedDate.value.year.toString();
      }

      final revenueResult = await _dataController.getDateVsRevenue(queryParams);
      final salesActivityResult = await _dataController.getDateVsSale(queryParams);

      _processChartData(revenueResult, salesActivityResult);

    } catch (err) {
      Get.snackbar('Error', err.toString().replaceAll('Exception: ', ''), backgroundColor: kErrorColor, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  // UPDATED: This method now correctly aggregates data for month and year views.
  void _processChartData(List<dynamic> revenueResult, List<dynamic> salesActivityResult) {
    switch (filterType.value) {
      case PerformanceFilterType.Day:
      // Create a 12-hour window centered-ish around the selected hour:
      // start = selectedDate - 5 hours, end = start + 11 hours => 12 hourly buckets
        final DateTime sel = selectedDate.value;
        final DateTime startWindow = DateTime(sel.year, sel.month, sel.day, sel.hour).subtract(const Duration(hours: 5));
        final DateTime endWindow = startWindow.add(const Duration(hours: 11));

        // Initialize 12 hourly buckets
        final Map<DateTime, double> hourlyRevenue = {};
        for (int i = 0; i < 12; i++) {
          final dt = startWindow.add(Duration(hours: i));
          hourlyRevenue[DateTime(dt.year, dt.month, dt.day, dt.hour)] = 0.0;
        }

        // Aggregate revenue into hourly buckets (converting API times to local)
        for (var item in revenueResult) {
          final DateTime dt = DateTime.parse(item['date']).toLocal();
          if (!dt.isBefore(startWindow) && !dt.isAfter(endWindow.add(const Duration(hours: 1)))) {
            final bucket = DateTime(dt.year, dt.month, dt.day, dt.hour);
            if (hourlyRevenue.containsKey(bucket)) {
              hourlyRevenue[bucket] = (hourlyRevenue[bucket] ?? 0) + (item['net_revenue'] as num).toDouble();
            }
          }
        }

        final sortedHourlyKeys = hourlyRevenue.keys.toList()..sort();
        revenueData.value = sortedHourlyKeys
            .map((k) => RevenueData(k, hourlyRevenue[k]!))
            .toList();

        // Sales activity: aggregate sales per hour (if provided) similar to hourlyData earlier
        final Map<int, SalesActivityData> hourlyData = {};
        for (var item in salesActivityResult) {
          final hour = item['sale_hour'] as int;
          final sales = item['nSales'] as int;
          final customers = item['nCustomers'] as int;
          if (hourlyData.containsKey(hour)) {
            hourlyData[hour] = SalesActivityData(
                '${hour.toString().padLeft(2, '0')}:00',
                hourlyData[hour]!.salesCount + sales,
                hourlyData[hour]!.customerCount + customers);
          } else {
            hourlyData[hour] = SalesActivityData(
                '${hour.toString().padLeft(2, '0')}:00', sales, customers);
          }
        }
        var sortedHours = hourlyData.keys.toList()..sort();
        salesActivityData.value = sortedHours.map((hour) => hourlyData[hour]!).toList();
        break;


      case PerformanceFilterType.Month:
        final Map<int, double> dailyRevenue = {};
        for (var item in revenueResult) {
          final day = DateTime.parse(item['date']).day;
          final revenue = (item['net_revenue'] as num).toDouble();
          dailyRevenue[day] = (dailyRevenue[day] ?? 0) + revenue;
        }
        var sortedRevenueDays = dailyRevenue.keys.toList()..sort();
        revenueData.value = sortedRevenueDays.map((day) => RevenueData(day.toString(), dailyRevenue[day]!)).toList();

        final Map<int, Map<String, int>> dailySales = {};
        for (var item in salesActivityResult) {
          final day = DateTime.parse(item['sale_date']).day;
          if (!dailySales.containsKey(day)) {
            dailySales[day] = {'nSales': 0, 'nCustomers': 0};
          }
          dailySales[day]!['nSales'] = dailySales[day]!['nSales']! + (item['nSales'] as int);
          dailySales[day]!['nCustomers'] = dailySales[day]!['nCustomers']! + (item['nCustomers'] as int);
        }
        var sortedSalesDays = dailySales.keys.toList()..sort();
        salesActivityData.value = sortedSalesDays.map((day) => SalesActivityData(day.toString(), dailySales[day]!['nSales']!, dailySales[day]!['nCustomers']!)).toList();
        break;

      case PerformanceFilterType.Year:
        final Map<int, double> monthlyRevenue = {};
        for (var item in revenueResult) {
          final month = DateTime.parse(item['date']).month;
          final revenue = (item['net_revenue'] as num).toDouble();
          monthlyRevenue[month] = (monthlyRevenue[month] ?? 0) + revenue;
        }
        var sortedRevenueMonths = monthlyRevenue.keys.toList()..sort();
        revenueData.value = sortedRevenueMonths.map((month) => RevenueData(DateFormat.MMM().format(DateTime(0, month)), monthlyRevenue[month]!)).toList();

        final Map<int, Map<String, int>> monthlySales = {};
        for (var item in salesActivityResult) {
          final month = DateTime.parse(item['sale_date']).month;
          if (!monthlySales.containsKey(month)) {
            monthlySales[month] = {'nSales': 0, 'nCustomers': 0};
          }
          monthlySales[month]!['nSales'] = monthlySales[month]!['nSales']! + (item['nSales'] as int);
          monthlySales[month]!['nCustomers'] = monthlySales[month]!['nCustomers']! + (item['nCustomers'] as int);
        }
        var sortedSalesMonths = monthlySales.keys.toList()..sort();
        salesActivityData.value = sortedSalesMonths.map((month) => SalesActivityData(DateFormat.MMM().format(DateTime(0, month)), monthlySales[month]!['nSales']!, monthlySales[month]!['nCustomers']!)).toList();
        break;
    }
  }

  void changeFilterType(PerformanceFilterType newFilter) {
    filterType.value = newFilter;
    fetchPerformanceData();
  }

  void pickDate(BuildContext context) async {
    final newDate = await showDatePicker(
        context: context,
        initialDate: selectedDate.value,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDatePickerMode: filterType.value == PerformanceFilterType.Year ? DatePickerMode.year : DatePickerMode.day
    );
    if (newDate != null && newDate != selectedDate.value) {
      selectedDate.value = newDate;
      fetchPerformanceData();
    }
  }
}

// --- UI WIDGET ---
class PerformanceAnalysisPage extends StatelessWidget {
  const PerformanceAnalysisPage({super.key});
  static const route_name = performance_analysis_route;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PerformanceUIController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        title: Text('Performance Analysis', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () => controller.pickDate(context),
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _FilterAndSummarySection(),
              const SizedBox(height: 24),
            _ChartCard(
              title: '${controller.filterType.value.titleName} Revenue',
              child: _RevenueChart(
                data: controller.revenueData,
                filterType: controller.filterType.value,
                selectedDate: controller.selectedDate.value,
              ),
            ),

              const SizedBox(height: 16),
              _ChartCard(
                title: '${controller.filterType.value.titleName} Sales Activity',
                child: _SalesActivityChart(data: controller.salesActivityData, filterType: controller.filterType.value),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _FilterAndSummarySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PerformanceUIController>();
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Column(
      children: [
        Obx(() => SegmentedButton<PerformanceFilterType>(
          segments: const [
            ButtonSegment(value: PerformanceFilterType.Day, label: Text('Day')),
            ButtonSegment(value: PerformanceFilterType.Month, label: Text('Month')),
            ButtonSegment(value: PerformanceFilterType.Year, label: Text('Year')),
          ],
          selected: {controller.filterType.value},
          onSelectionChanged: (newSelection) {
            controller.changeFilterType(newSelection.first);
          },
        )),
        const SizedBox(height: 16),
        Obx(() {
          String formattedDate;
          switch(controller.filterType.value) {
            case PerformanceFilterType.Day:
              formattedDate = DateFormat('EEEE, d MMMM yyyy').format(controller.selectedDate.value);
              break;
            case PerformanceFilterType.Month:
              formattedDate = DateFormat('MMMM yyyy').format(controller.selectedDate.value);
              break;
            case PerformanceFilterType.Year:
              formattedDate = DateFormat('yyyy').format(controller.selectedDate.value);
              break;
          }
          return Text(formattedDate, style: theme.textTheme.headlineSmall);
        }),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.wallet_outlined,
                label: 'Total Revenue',
                value: currencyFormatter.format(controller.totalRevenue),
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.receipt_long_outlined,
                label: 'Total Sales',
                value: controller.totalSales.toString(),
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}


class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(height: 250, child: child),
        ],
      ),
    );
  }
}
class _RevenueChart extends StatelessWidget {
  final List<RevenueData> data;
  final PerformanceFilterType filterType;
  final DateTime selectedDate;

  const _RevenueChart({
    required this.data,
    required this.filterType,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return const Center(child: Text("No revenue data available."));

    if (filterType == PerformanceFilterType.Day) {
      // Determine the same visible window used while aggregating:
      final DateTime startWindow = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedDate.hour)
          .subtract(const Duration(hours: 5));
      final DateTime endWindow = startWindow.add(const Duration(hours: 11));

      return SfCartesianChart(
        primaryXAxis: DateTimeAxis(
          edgeLabelPlacement: EdgeLabelPlacement.shift,
          dateFormat: DateFormat.Hm(), // shows "13:00" style
          intervalType: DateTimeIntervalType.hours,
          interval: 1,
          initialVisibleMinimum: startWindow,
          initialVisibleMaximum: endWindow,
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: theme.textTheme.bodySmall,
        ),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹'),
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelStyle: theme.textTheme.bodySmall,
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<RevenueData, DateTime>>[
          SplineSeries<RevenueData, DateTime>(
            dataSource: data,
            xValueMapper: (RevenueData sales, _) => sales.xValue as DateTime,
            yValueMapper: (RevenueData sales, _) => sales.netRevenue,
            name: 'Revenue',
            markerSettings: const MarkerSettings(isVisible: true),
          )
        ],
      );
    } else {
      // existing behavior for Month/Year
      return SfCartesianChart(
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: theme.textTheme.bodySmall,
        ),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹'),
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelStyle: theme.textTheme.bodySmall,
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<RevenueData, dynamic>>[
          SplineSeries<RevenueData, dynamic>(
            dataSource: data,
            xValueMapper: (RevenueData sales, _) => sales.xValue,
            yValueMapper: (RevenueData sales, _) => sales.netRevenue,
            name: 'Revenue',
            markerSettings: const MarkerSettings(isVisible: true),
          ),
        ],
      );
    }
  }
}

class _SalesActivityChart extends StatelessWidget {
  final List<SalesActivityData> data;
  final PerformanceFilterType filterType;
  const _SalesActivityChart({required this.data, required this.filterType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return const Center(child: Text("No sales activity available."));

    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        labelStyle: theme.textTheme.bodySmall,
      ),
      primaryYAxis: NumericAxis(
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: theme.textTheme.bodySmall,
      ),
      tooltipBehavior: TooltipBehavior(enable: true, shared: true),
      legend: Legend(isVisible: true, position: LegendPosition.bottom),
      series: <CartesianSeries<SalesActivityData, dynamic>>[
        ColumnSeries<SalesActivityData, dynamic>(
          dataSource: data,
          xValueMapper: (SalesActivityData sales, _) => sales.xValue.toString(),
          yValueMapper: (SalesActivityData sales, _) => sales.salesCount,
          name: 'Sales',
          // color: theme.primaryColor,
        ),
        ColumnSeries<SalesActivityData, dynamic>(
          dataSource: data,
          xValueMapper: (SalesActivityData sales, _) => sales.xValue.toString(),
          yValueMapper: (SalesActivityData sales, _) => sales.customerCount,
          name: 'Customers',
          color: Colors.orange,
        )
      ],
    );
  }
}

