import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/portfolio_item.dart';
import '../providers/currency_provider.dart';
import '../screens/stock_detail_screen.dart';

class StockCard extends StatelessWidget {
  final PortfolioItem item;
  final VoidCallback onDelete;
  final bool hidden;

  const StockCard({super.key, required this.item, required this.onDelete, this.hidden = false});

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CurrencyProvider>();
    final stock = item.stock;
    final gainLoss = item.gainLoss;
    final gainPct = item.gainLossPercent;
    final isPositive = gainLoss >= 0;
    final gainColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
    final dayChange = stock?.change ?? 0;
    final dayPct = stock?.percentChange ?? 0;
    final dayPositive = dayChange >= 0;
    final dayColor = dayPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockDetailScreen(symbol: item.symbol),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.symbol,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${item.shares % 1 == 0 ? item.shares.toInt() : item.shares} shares',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    color: Colors.grey,
                    tooltip: 'Remove',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatColumn(
                    label: 'Price',
                    value: stock == null
                        ? '--'
                        : hidden ? '••••••' : cp.format(stock.currentPrice),
                    sub: stock != null
                        ? Row(
                            children: [
                              Icon(
                                dayPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                color: dayColor,
                                size: 16,
                              ),
                              Text(
                                hidden
                                    ? '${dayPositive ? '+' : ''}${dayPct.toStringAsFixed(2)}%'
                                    : '${dayPositive ? '+' : ''}${cp.format(dayChange)}  '
                                      '(${dayPositive ? '+' : ''}${dayPct.toStringAsFixed(2)}%)',
                                style: TextStyle(color: dayColor, fontSize: 12),
                              ),
                            ],
                          )
                        : null,
                  ),
                  _StatColumn(
                    label: 'Total Value',
                    value: stock == null
                        ? '--'
                        : hidden ? '••••••' : cp.format(item.currentValue),
                  ),
                  _StatColumn(
                    label: 'Gain / Loss',
                    value: stock == null
                        ? '--'
                        : hidden
                            ? '${isPositive ? '+' : ''}${gainPct.toStringAsFixed(2)}%'
                            : '${isPositive ? '+' : ''}${cp.format(gainLoss)}',
                    sub: (stock != null && !hidden)
                        ? Text(
                            '${isPositive ? '+' : ''}${gainPct.toStringAsFixed(2)}%',
                            style: TextStyle(color: gainColor, fontSize: 12),
                          )
                        : null,
                    valueColor: stock != null ? gainColor : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Widget? sub;
  final Color? valueColor;

  const _StatColumn({required this.label, required this.value, this.sub, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor),
        ),
        ?sub,
      ],
    );
  }
}

