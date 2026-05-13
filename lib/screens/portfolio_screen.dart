import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';
import '../widgets/stock_card.dart';
import 'add_stock_screen.dart';
import 'allocation_screen.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            icon: Icon(_hidden ? Icons.visibility_off : Icons.visibility),
            tooltip: _hidden ? 'Show values' : 'Hide values',
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
          Consumer<PortfolioProvider>(
            builder: (ctx, p, _) => IconButton(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Sort',
              onPressed: () => _showSortSheet(ctx, p),
            ),
          ),
          Consumer<CurrencyProvider>(
            builder: (ctx, cp, _) => GestureDetector(
              onTap: () => _showCurrencySheet(ctx, cp),
              child: Container(
                margin: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    cp.code,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Consumer<PortfolioProvider>(
            builder: (_, p, _) => IconButton(
              icon: p.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: p.isLoading ? null : p.refresh,
              tooltip: 'Refresh prices',
            ),
          ),
        ],
      ),
      body: Consumer<PortfolioProvider>(
        builder: (context, provider, _) {
          if (provider.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
              );
            });
          }
          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                    child: _SummaryHeader(provider: provider, hidden: _hidden)),
                SliverToBoxAdapter(child: _PortfolioChart(provider: provider)),
                if (provider.items.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final item = provider.items[i];
                        return StockCard(
                          item: item,
                          hidden: _hidden,
                          onDelete: () => _confirmDelete(context, provider, item.symbol),
                        );
                      },
                      childCount: provider.items.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddStockScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PortfolioProvider provider, String symbol) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $symbol?'),
        content: const Text('This will remove the position from your portfolio.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.removeItem(symbol);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

void _showSortSheet(BuildContext context, PortfolioProvider provider) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SortSheet(provider: provider),
  );
}

void _showCurrencySheet(BuildContext context, CurrencyProvider cp) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CurrencySheet(cp: cp),
  );
}

class _SortSheet extends StatelessWidget {
  final PortfolioProvider provider;
  const _SortSheet({required this.provider});

  static const _options = [
    (PortfolioSort.value,        'Total Value',   Icons.trending_up_rounded),
    (PortfolioSort.alphabetical, 'Alphabetical',  Icons.sort_by_alpha_rounded),
    (PortfolioSort.shares,       'Shares',        Icons.pie_chart_outline_rounded),
    (PortfolioSort.price,        'Stock Price',   Icons.attach_money_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort By',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            for (final (sort, label, icon) in _options)
              ListTile(
                leading: Icon(icon,
                    color: provider.sort == sort
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                title: Text(label,
                    style: TextStyle(
                      fontWeight: provider.sort == sort
                          ? FontWeight.w600
                          : FontWeight.normal,
                    )),
                trailing: provider.sort == sort
                    ? Icon(Icons.check_rounded,
                        color: theme.colorScheme.primary)
                    : null,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: provider.sort == sort
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : null,
                onTap: () {
                  provider.setSort(sort);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CurrencySheet extends StatelessWidget {
  final CurrencyProvider cp;
  const _CurrencySheet({required this.cp});

  static const _flags = {
    'USD': '🇺🇸',
    'CAD': '🇨🇦',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Currency',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            for (final code in CurrencyProvider.currencies)
              ListTile(
                leading: Text(_flags[code] ?? '', style: const TextStyle(fontSize: 22)),
                title: Text(cp.nameOf(code),
                    style: TextStyle(
                      fontWeight: cp.code == code
                          ? FontWeight.w600
                          : FontWeight.normal,
                    )),
                subtitle: Text(code,
                    style: TextStyle(
                        color: theme.colorScheme.primary, fontSize: 12)),
                trailing: cp.code == code
                    ? Icon(Icons.check_rounded,
                        color: theme.colorScheme.primary)
                    : null,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: cp.code == code
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : null,
                onTap: () {
                  cp.setCurrency(code);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final PortfolioProvider provider;
  final bool hidden;

  const _SummaryHeader({required this.provider, required this.hidden});

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
    final cp = context.watch<CurrencyProvider>();
    final gl = provider.totalGainLoss;
    final glPct = provider.totalGainLossPercent;
    final isPos = gl >= 0;
    final glColor = isPos ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
    final dayChange = provider.totalDayChange;
    final dayPos = dayChange >= 0;
    final dayColor = dayPos ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
    final prevValue = provider.totalValue - dayChange;
    final dayPct = prevValue > 0 ? (dayChange / prevValue) * 100 : 0.0;
    final theme = Theme.of(context);

    final pieItems = provider.items.where((i) => i.currentValue > 0).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Portfolio Value',
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  hidden ? '••••••' : cp.format(provider.totalValue),
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (provider.totalValue > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        dayPos ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: dayColor,
                        size: 18,
                      ),
                      Text(
                        hidden
                            ? '${dayPos ? '+' : ''}${dayPct.toStringAsFixed(2)}%  today'
                            : '${dayPos ? '+' : ''}${cp.format(dayChange)}  '
                              '(${dayPos ? '+' : ''}${dayPct.toStringAsFixed(2)}%)  today',
                        style: TextStyle(
                          color: dayColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryChip(
                        label: 'Cost Basis',
                        value: hidden ? '••••••' : cp.format(provider.totalCost),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryChip(
                        label: 'Gain / Loss',
                        value: hidden
                            ? '${isPos ? '+' : ''}${glPct.toStringAsFixed(2)}%'
                            : '${isPos ? '+' : ''}${cp.format(gl)}',
                        sub: hidden ? null : '${isPos ? '+' : ''}${glPct.toStringAsFixed(2)}%',
                        valueColor: glColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryChip(
                        label: 'Dividends',
                        value: hidden ? '••••••' : cp.format(provider.totalDividendsReceived),
                        valueColor: hidden ? null : const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryChip(
                        label: 'Realized Gains',
                        value: hidden
                            ? '••••••'
                            : '${provider.totalRealizedGains >= 0 ? '+' : ''}${cp.format(provider.totalRealizedGains)}',
                        valueColor: hidden
                            ? null
                            : (provider.totalRealizedGains >= 0
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFEF5350)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (pieItems.length >= 2) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllocationScreen()),
              ),
              child: SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(enabled: false),
                    sections: pieItems.asMap().entries.map((e) {
                      final i = e.key;
                      final item = e.value;
                      return PieChartSectionData(
                        value: item.currentValue,
                        title: '',
                        radius: 40,
                        color: _colors[i % _colors.length],
                      );
                    }).toList(),
                    centerSpaceRadius: 18,
                    sectionsSpace: 2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;

  const _SummaryChip({required this.label, required this.value, this.sub, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        if (sub != null)
          Text(sub!, style: TextStyle(fontSize: 12, color: valueColor ?? Colors.grey)),
      ],
    );
  }
}


class _PortfolioChart extends StatelessWidget {
  final PortfolioProvider provider;
  const _PortfolioChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final history = provider.snapshotHistory;
    if (history.length < 2) return const SizedBox.shrink();

    final values = history.map((e) => e.$2).toList();
    final minY = values.reduce(min) * 0.995;
    final maxY = values.reduce(max) * 1.005;
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.$2))
        .toList();

    final first = history.first.$1;
    final last = history.last.$1;
    final dayCount = last.difference(first).inDays + 1;
    final rangeLabel = dayCount <= 7
        ? '7 days'
        : dayCount <= 31
            ? '${dayCount}d'
            : '${(dayCount / 30).round()}mo';

    final isUp = values.last >= values.first;
    final lineColor =
        isUp ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Portfolio Value',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(rangeLabel,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          lineColor.withValues(alpha: 0.2),
                          lineColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No positions yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first stock',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
