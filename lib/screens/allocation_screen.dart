import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';

class AllocationScreen extends StatefulWidget {
  const AllocationScreen({super.key});

  @override
  State<AllocationScreen> createState() => _AllocationScreenState();
}

class _AllocationScreenState extends State<AllocationScreen> {
  int _touched = -1;

  static const _colors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFFC107),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allocation')),
      body: Consumer<PortfolioProvider>(
        builder: (context, provider, _) {
          final cp = context.watch<CurrencyProvider>();
          final items = provider.items.where((i) => i.currentValue > 0).toList();
          final total = provider.totalValue;

          if (items.isEmpty) {
            return const Center(child: Text('No positions'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            children: [
              SizedBox(
                height: 280,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          _touched = response?.touchedSection?.touchedSectionIndex ?? -1;
                        });
                      },
                    ),
                    sections: items.asMap().entries.map((e) {
                      final i = e.key;
                      final item = e.value;
                      final pct = total > 0 ? item.currentValue / total * 100 : 0;
                      final isTouched = i == _touched;
                      return PieChartSectionData(
                        value: item.currentValue,
                        title: '${pct.toStringAsFixed(1)}%',
                        radius: isTouched ? 115 : 100,
                        color: _colors[i % _colors.length],
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ...items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final pct = total > 0 ? item.currentValue / total * 100 : 0;
                return Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _colors[i % _colors.length],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item.symbol,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              cp.format(item.currentValue),
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                            Text(
                              '${pct.toStringAsFixed(2)}%',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (i < items.length - 1)
                      Divider(color: Colors.grey.withValues(alpha: 0.2), height: 24),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
