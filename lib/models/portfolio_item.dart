import 'price_alert.dart';
import 'stock.dart';
import 'stock_purchase.dart';

class PortfolioItem {
  final String symbol;
  final List<StockPurchase> purchases;
  double dividendsReceived;
  List<PriceAlert> alerts;
  Stock? stock;

  PortfolioItem({
    required this.symbol,
    required this.purchases,
    this.dividendsReceived = 0,
    List<PriceAlert>? alerts,
    this.stock,
  }) : alerts = alerts ?? [];

  double get shares => purchases.fold(0, (s, p) => s + p.shares);
  double get costBasis => purchases.fold(0, (s, p) => s + p.totalCost);
  double get avgCost => shares > 0 ? costBasis / shares : 0;
  double get currentValue => (stock?.currentPrice ?? 0) * shares;
  double get gainLoss => currentValue - costBasis;
  double get gainLossPercent => costBasis > 0 ? (gainLoss / costBasis) * 100 : 0;
  double get estimatedAnnualIncome => (stock?.annualDividendPerShare ?? 0) * shares;

  DateTime? get earliestPurchaseDate => purchases.isEmpty
      ? null
      : purchases.map((p) => p.date).reduce((a, b) => a.isBefore(b) ? a : b);

  List<StockPurchase> get sortedPurchases =>
      [...purchases]..sort((a, b) => a.date.compareTo(b.date));

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'purchases': purchases.map((p) => p.toJson()).toList(),
        'dividendsReceived': dividendsReceived,
        'alerts': alerts.map((a) => a.toJson()).toList(),
      };

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    final List<StockPurchase> purchases;
    if (json.containsKey('purchases')) {
      purchases = (json['purchases'] as List)
          .map((e) => StockPurchase.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      purchases = [
        StockPurchase(
          shares: (json['shares'] as num).toDouble(),
          pricePerShare: (json['avgCost'] as num).toDouble(),
          date: DateTime(2020, 1, 1),
        )
      ];
    }

    // Migrate legacy alertHigh / alertLow fields
    final alerts = <PriceAlert>[];
    if (json['alerts'] != null) {
      alerts.addAll((json['alerts'] as List)
          .map((e) => PriceAlert.fromJson(e as Map<String, dynamic>)));
    } else {
      final high = (json['alertHigh'] as num?)?.toDouble();
      final low = (json['alertLow'] as num?)?.toDouble();
      if (high != null) {
        alerts.add(PriceAlert(
          id: 'legacy_high',
          type: AlertType.price,
          direction: AlertDirection.above,
          value: high,
          targetPrice: high,
        ));
      }
      if (low != null) {
        alerts.add(PriceAlert(
          id: 'legacy_low',
          type: AlertType.price,
          direction: AlertDirection.below,
          value: low,
          targetPrice: low,
        ));
      }
    }

    return PortfolioItem(
      symbol: json['symbol'] as String,
      purchases: purchases,
      dividendsReceived: (json['dividendsReceived'] as num?)?.toDouble() ?? 0,
      alerts: alerts,
    );
  }
}
