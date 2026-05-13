import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/price_alert.dart';
import '../models/watchlist_item.dart';
import '../providers/currency_provider.dart';
import '../providers/watchlist_provider.dart';

void _showAlertSheet(BuildContext context, WatchlistItem item, WatchlistProvider provider) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _WatchlistAlertSheet(item: item, provider: provider),
  );
}

class _WatchlistAlertSheet extends StatefulWidget {
  final WatchlistItem item;
  final WatchlistProvider provider;
  const _WatchlistAlertSheet({required this.item, required this.provider});

  @override
  State<_WatchlistAlertSheet> createState() => _WatchlistAlertSheetState();
}

class _WatchlistAlertSheetState extends State<_WatchlistAlertSheet> {
  AlertType _type = AlertType.price;
  AlertDirection _direction = AlertDirection.above;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addAlert() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v <= 0) return;
    final currentPrice = widget.item.stock?.currentPrice ?? 0;
    widget.provider.addAlert(
      widget.item.symbol,
      PriceAlert.create(
        type: _type,
        direction: _direction,
        value: v,
        currentPrice: currentPrice,
      ),
    );
    _ctrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Price Alerts — ${item.symbol}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (item.alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('No alerts set.',
                  style: TextStyle(color: Colors.grey.shade500)),
            )
          else
            ...item.alerts.map((alert) {
              final isAbove = alert.direction == AlertDirection.above;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAbove
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 16,
                      color: isAbove
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEF5350),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(alert.label,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        widget.provider.removeAlert(item.symbol, alert.id);
                        setState(() {});
                      },
                      color: Colors.grey,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 4),
          SegmentedButton<AlertType>(
            segments: const [
              ButtonSegment(value: AlertType.price, label: Text('Price \$')),
              ButtonSegment(value: AlertType.percent, label: Text('Percent %')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 8),
          SegmentedButton<AlertDirection>(
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        _type == AlertType.price ? 'Price (\$)' : 'Percent (%)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addAlert(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed: _addAlert,
                style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          Consumer<WatchlistProvider>(
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
      body: Consumer<WatchlistProvider>(
        builder: (context, provider, _) {
          if (provider.items.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: provider.items.length,
              itemBuilder: (context, i) {
                final item = provider.items[i];
                return _WatchlistCard(
                  item: item,
                  onDelete: () => provider.removeItem(item.symbol),
                  onAlert: () => _showAlertSheet(context, item, provider),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Watchlist'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Ticker Symbol',
            hintText: 'e.g. TSLA',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (_) => _submit(ctx, context, ctrl),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => _submit(ctx, context, ctrl),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _submit(
      BuildContext dialogCtx, BuildContext screenCtx, TextEditingController ctrl) {
    final symbol = ctrl.text.trim();
    if (symbol.isEmpty) return;
    Navigator.pop(dialogCtx);
    screenCtx.read<WatchlistProvider>().addItem(symbol).then((success) {
      if (!success && screenCtx.mounted) {
        ScaffoldMessenger.of(screenCtx).showSnackBar(
          const SnackBar(
              content: Text('Invalid symbol or already in watchlist.')),
        );
      }
    });
  }
}

class _WatchlistCard extends StatelessWidget {
  final WatchlistItem item;
  final VoidCallback onDelete;
  final VoidCallback onAlert;

  const _WatchlistCard({required this.item, required this.onDelete, required this.onAlert});

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CurrencyProvider>();
    final stock = item.stock;
    final change = stock?.change ?? 0;
    final pct = stock?.percentChange ?? 0;
    final isPos = change >= 0;
    final color = isPos ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
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
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stock != null ? cp.format(stock.currentPrice) : '--',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                if (stock != null)
                  Row(
                    children: [
                      Icon(
                        isPos ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: color,
                        size: 16,
                      ),
                      Text(
                        '${isPos ? '+' : ''}${pct.toStringAsFixed(2)}%',
                        style: TextStyle(color: color, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                item.alerts.isNotEmpty
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                size: 20,
              ),
              onPressed: onAlert,
              color: item.alerts.isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              tooltip: 'Set alert',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              color: Colors.grey,
              tooltip: 'Remove',
            ),
          ],
        ),
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
          Icon(Icons.bookmark_border, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Watchlist is empty',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + Add to Watchlist to get started',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
