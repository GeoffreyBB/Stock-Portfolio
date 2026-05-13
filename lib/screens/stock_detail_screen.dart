import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/price_alert.dart';
import '../models/stock_purchase.dart';
import '../models/stock_sale.dart';
import '../providers/currency_provider.dart';
import '../providers/portfolio_provider.dart';
import 'sell_stock_screen.dart';

final _dateFmt = DateFormat('MMM d, y');

class StockDetailScreen extends StatefulWidget {
  final String symbol;
  const StockDetailScreen({super.key, required this.symbol});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {

  @override
  Widget build(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, provider, _) {
        final cp = context.watch<CurrencyProvider>();
        final itemIdx =
            provider.items.indexWhere((i) => i.symbol == widget.symbol);
        if (itemIdx == -1) {
          // Position was fully sold — close screen
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Navigator.pop(context));
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final item = provider.items[itemIdx];
        final stock = item.stock;
        final dayChange = stock?.change ?? 0;
        final dayPct = stock?.percentChange ?? 0;
        final dayPositive = dayChange >= 0;
        final dayColor =
            dayPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
        final gainLoss = item.gainLoss;
        final gainPct = item.gainLossPercent;
        final isPositive = gainLoss >= 0;
        final gainColor =
            isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
        final annualDiv = stock?.annualDividendPerShare ?? 0;
        final divYield = (stock != null && stock.currentPrice > 0)
            ? annualDiv / stock.currentPrice
            : 0.0;
        final paysDividend = annualDiv > 0;
        final sales = provider.salesForSymbol(widget.symbol);
        final totalRealized = sales.fold(0.0, (s, e) => s + e.realizedGain);
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.symbol),
            centerTitle: false,
            actions: [
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellStockScreen(symbol: widget.symbol),
                  ),
                ),
                child: const Text('Sell'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Price header ---
                Text(
                  stock != null ? cp.format(stock.currentPrice) : '--',
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (stock != null)
                  Row(
                    children: [
                      Icon(
                        dayPositive
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: dayColor,
                        size: 22,
                      ),
                      Text(
                        '${dayPositive ? '+' : ''}${cp.format(dayChange)}  '
                        '(${dayPositive ? '+' : ''}${dayPct.toStringAsFixed(2)}%)',
                        style: TextStyle(
                            color: dayColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                // --- Price chart ---
                if (stock != null && stock.sparklineData.length >= 2) ...[
                  const SizedBox(height: 16),
                  _PriceChart(
                    prices: stock.sparklineData,
                    dates: stock.sparklineDates,
                  ),
                ],

                const SizedBox(height: 24),

                // --- Position summary ---
                _SectionLabel('Your Position'),
                const SizedBox(height: 12),
                _StatGrid(children: [
                  _GridCell(
                    label: 'Shares',
                    value: item.shares % 1 == 0
                        ? item.shares.toInt().toString()
                        : item.shares.toString(),
                  ),
                  _GridCell(
                      label: 'Avg Cost',
                      value: cp.format(item.avgCost)),
                  _GridCell(
                    label: 'Total Value',
                    value:
                        stock != null ? cp.format(item.currentValue) : '--',
                  ),
                  _GridCell(
                      label: 'Cost Basis',
                      value: cp.format(item.costBasis)),
                  _GridCell(
                    label: 'Gain / Loss',
                    value: stock != null
                        ? '${isPositive ? '+' : ''}${cp.format(gainLoss)}'
                        : '--',
                    valueColor: stock != null ? gainColor : null,
                  ),
                  _GridCell(
                    label: 'Return',
                    value: stock != null
                        ? '${isPositive ? '+' : ''}${gainPct.toStringAsFixed(2)}%'
                        : '--',
                    valueColor: stock != null ? gainColor : null,
                  ),
                ]),

                // --- Today's range ---
                if (stock != null) ...[
                  const SizedBox(height: 24),
                  _SectionLabel("Today's Range"),
                  const SizedBox(height: 12),
                  _StatGrid(children: [
                    _GridCell(
                        label: 'Open',
                        value: cp.format(stock.open)),
                    _GridCell(
                        label: 'High',
                        value: cp.format(stock.high)),
                    _GridCell(
                        label: 'Low', value: cp.format(stock.low)),
                    _GridCell(
                        label: 'Prev Close',
                        value: cp.format(stock.previousClose)),
                  ]),
                ],

                // --- Price alerts ---
                const SizedBox(height: 24),
                _SectionLabel('Price Alerts'),
                const SizedBox(height: 12),
                ...item.alerts.map((alert) => _AlertRow(
                      alert: alert,
                      onDelete: () =>
                          provider.removeAlert(widget.symbol, alert.id),
                    )),
                if (item.alerts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('No alerts set.',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ),
                _AddAlertForm(
                  currentPrice: stock?.currentPrice ?? 0,
                  onAdd: (alert) => provider.addAlert(widget.symbol, alert),
                ),

                // --- Purchase history ---
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionLabel('Purchase History'),
                    Text(
                      '${item.purchases.length} ${item.purchases.length == 1 ? 'lot' : 'lots'}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...item.sortedPurchases
                    .map((p) => _PurchaseRow(purchase: p)),

                // --- Realized gains ---
                if (sales.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionLabel('Realized Gains'),
                  const SizedBox(height: 12),
                  ...sales.map((s) => _SaleRow(sale: s)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: (totalRealized >= 0
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFEF5350))
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Realized',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${totalRealized >= 0 ? '+' : ''}${cp.format(totalRealized)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: totalRealized >= 0
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFEF5350),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // --- Dividends ---
                const SizedBox(height: 24),
                _SectionLabel('Dividends'),
                const SizedBox(height: 12),
                if (!paysDividend)
                  Text('This stock does not pay a dividend.',
                      style: TextStyle(color: Colors.grey.shade500))
                else
                  _StatGrid(children: [
                    _GridCell(
                        label: 'Annual Div / Share',
                        value: cp.format(annualDiv)),
                    _GridCell(
                        label: 'Dividend Yield',
                        value:
                            '${(divYield * 100).toStringAsFixed(2)}%'),
                    _GridCell(
                        label: 'Est. Annual Income',
                        value: cp.format(item.estimatedAnnualIncome),
                        valueColor: const Color(0xFF4CAF50)),
                  ]),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dividends Received',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            cp.format(item.dividendsReceived),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4CAF50)),
                          ),
                        ],
                      ),
                      Text('Auto-tracked',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Price chart ────────────────────────────────────────────────────────────

class _PriceChart extends StatelessWidget {
  final List<double> prices;
  final List<DateTime> dates;
  const _PriceChart({required this.prices, required this.dates});

  @override
  Widget build(BuildContext context) {
    final isUp = prices.last >= prices.first;
    final color = isUp ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);

    final minY = prices.reduce(min);
    final maxY = prices.reduce(max);
    final yRange = maxY == minY ? 1.0 : maxY - minY;
    final yPad = yRange * 0.12;
    final yMin = minY - yPad;
    final yMax = maxY + yPad;
    final yInterval = (yMax - yMin) / 4;

    final spots = prices
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    // Label the first data point of each new month
    final monthChangeIndices = <int>{0};
    for (int i = 1; i < dates.length; i++) {
      if (dates[i].month != dates[i - 1].month) monthChangeIndices.add(i);
    }
    final monthFmt = DateFormat('MMM');
    final tooltipFmt = DateFormat('MMM d');

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: yMin,
          maxY: yMax,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.1),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                interval: yInterval,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min || v == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      v.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= dates.length) {
                    return const SizedBox.shrink();
                  }
                  if (!monthChangeIndices.contains(i)) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    monthFmt.format(dates[i]),
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withValues(alpha: 0.15),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              getTooltipItems: (touchedSpots) =>
                  touchedSpots.map((s) {
                final i = s.x.round();
                final date =
                    (i >= 0 && i < dates.length) ? dates[i] : null;
                return LineTooltipItem(
                  date != null
                      ? '${tooltipFmt.format(date)}\n\$${s.y.toStringAsFixed(2)}'
                      : '\$${s.y.toStringAsFixed(2)}',
                  const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared layout helpers ──────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
}

class _StatGrid extends StatelessWidget {
  final List<_GridCell> children;
  const _StatGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final cellWidth = (MediaQuery.of(context).size.width - 40 - 12) / 2;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children.map((cell) {
        return SizedBox(
          width: cellWidth,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: cell,
          ),
        );
      }).toList(),
    );
  }
}

class _GridCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _GridCell(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ],
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  final StockPurchase purchase;
  const _PurchaseRow({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CurrencyProvider>();
    final sharesStr = purchase.shares % 1 == 0
        ? purchase.shares.toInt().toString()
        : '${purchase.shares}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_dateFmt.format(purchase.date),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                '$sharesStr shares @ ${cp.format(purchase.pricePerShare)}',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          Text(cp.format(purchase.totalCost),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  final StockSale sale;
  const _SaleRow({required this.sale});

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CurrencyProvider>();
    final isGain = sale.realizedGain >= 0;
    final color =
        isGain ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
    final sharesStr = sale.shares % 1 == 0
        ? sale.shares.toInt().toString()
        : '${sale.shares}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_dateFmt.format(sale.saleDate),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                '$sharesStr shares sold @ ${cp.format(sale.salePrice)}',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          Text(
            '${isGain ? '+' : ''}${cp.format(sale.realizedGain)}',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Alert widgets ──────────────────────────────────────────────────────────

class _AlertRow extends StatelessWidget {
  final PriceAlert alert;
  final VoidCallback onDelete;
  const _AlertRow({required this.alert, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isAbove = alert.direction == AlertDirection.above;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isAbove ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 16,
            color: isAbove ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(alert.label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onDelete,
            color: Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _AddAlertForm extends StatefulWidget {
  final double currentPrice;
  final void Function(PriceAlert) onAdd;
  const _AddAlertForm({required this.currentPrice, required this.onAdd});

  @override
  State<_AddAlertForm> createState() => _AddAlertFormState();
}

class _AddAlertFormState extends State<_AddAlertForm> {
  AlertType _type = AlertType.price;
  AlertDirection _direction = AlertDirection.above;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v <= 0) return;
    widget.onAdd(PriceAlert.create(
      type: _type,
      direction: _direction,
      value: v,
      currentPrice: widget.currentPrice,
    ));
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<AlertType>(
                segments: const [
                  ButtonSegment(value: AlertType.price, label: Text('Price \$')),
                  ButtonSegment(value: AlertType.percent, label: Text('Percent %')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<AlertDirection>(
                segments: const [
                  ButtonSegment(
                      value: AlertDirection.above,
                      icon: Icon(Icons.arrow_upward_rounded, size: 16),
                      label: Text('Above')),
                  ButtonSegment(
                      value: AlertDirection.below,
                      icon: Icon(Icons.arrow_downward_rounded, size: 16),
                      label: Text('Below')),
                ],
                selected: {_direction},
                onSelectionChanged: (s) => setState(() => _direction = s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _type == AlertType.price ? 'Price (\$)' : 'Percent (%)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }
}
