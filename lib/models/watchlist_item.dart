import 'price_alert.dart';
import 'stock.dart';

class WatchlistItem {
  final String symbol;
  Stock? stock;
  List<PriceAlert> alerts;

  WatchlistItem({required this.symbol, this.stock, List<PriceAlert>? alerts})
      : alerts = alerts ?? [];

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'alerts': alerts.map((a) => a.toJson()).toList(),
      };

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    final alerts = <PriceAlert>[];
    if (json['alerts'] != null) {
      alerts.addAll((json['alerts'] as List)
          .map((e) => PriceAlert.fromJson(e as Map<String, dynamic>)));
    } else {
      // Migrate legacy fields
      final high = (json['alertHigh'] as num?)?.toDouble();
      final low = (json['alertLow'] as num?)?.toDouble();
      if (high != null) {
        alerts.add(PriceAlert(
            id: 'legacy_high', type: AlertType.price,
            direction: AlertDirection.above, value: high, targetPrice: high));
      }
      if (low != null) {
        alerts.add(PriceAlert(
            id: 'legacy_low', type: AlertType.price,
            direction: AlertDirection.below, value: low, targetPrice: low));
      }
    }
    return WatchlistItem(symbol: json['symbol'] as String, alerts: alerts);
  }
}
