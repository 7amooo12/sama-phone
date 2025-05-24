import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/productivity_model.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/worker/performance_chart.dart';

class OwnerProductivityScreen extends StatefulWidget {
  const OwnerProductivityScreen({super.key});

  @override
  State<OwnerProductivityScreen> createState() =>
      _OwnerProductivityScreenState();
}

class _OwnerProductivityScreenState extends State<OwnerProductivityScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'إنتاجية العمال',
        hideStatusBarHeader: true,
      ),
      body: FutureBuilder<List<ProductivityModel>>(
        future: DatabaseService().getAllWorkersProductivity().first,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          if (!snapshot.hasData ||
              snapshot.data == null ||
              (snapshot.data as List).isEmpty) {
            return const Center(child: Text('لا توجد بيانات للإنتاجية'));
          }

          final List<ProductivityModel> entries =
              snapshot.data as List<ProductivityModel>;

          // Process data for the chart
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'إجمالي إنتاجية العمال',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Use the performance chart with performanceData
                PerformanceChart(
                  performanceData: _convertToChartData(entries),
                  title: 'إنتاجية العمال',
                ),
                const SizedBox(height: 24),

                // Worker performance list
                _buildWorkerList(entries),
              ],
            ),
          );
        },
      ),
    );
  }

  // Convert productivity data to chart format
  List<PerformanceData> _convertToChartData(List<ProductivityModel> entries) {
    // Group by worker
    final Map<String, double> workerProductivity = {};

    for (var entry in entries) {
      final workerName = entry.workerName;
      workerProductivity[workerName] =
          (workerProductivity[workerName] ?? 0) + entry.producedQuantity;
    }

    // Convert to chart data format
    return workerProductivity.entries.map((entry) {
      return PerformanceData(
        label: entry.key,
        value: entry.value,
      );
    }).toList();
  }

  Widget _buildWorkerList(List<ProductivityModel> entries) {
    // Group entries by worker
    final Map<String, List<ProductivityModel>> entriesByWorker = {};

    for (final entry in entries) {
      entriesByWorker.putIfAbsent(entry.workerName, () => []).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أداء العمال',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...entriesByWorker.entries.map((entry) {
          final workerName = entry.key;
          final workerEntries = entry.value;

          // Calculate average productivity (using efficiency instead of productivityScore)
          final totalProductivity = workerEntries.fold<double>(
              0, (sum, entry) => sum + entry.efficiency);
          final avgProductivity = workerEntries.isNotEmpty
              ? totalProductivity / workerEntries.length
              : 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'متوسط الإنتاجية: ${avgProductivity.toStringAsFixed(1)}'),
                  const SizedBox(height: 8),
                  Text('عدد الإدخالات: ${workerEntries.length}'),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
