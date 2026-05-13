class StockPurchase {
  final double shares;
  final double pricePerShare;
  final DateTime date;

  const StockPurchase({
    required this.shares,
    required this.pricePerShare,
    required this.date,
  });

  double get totalCost => shares * pricePerShare;

  Map<String, dynamic> toJson() => {
        'shares': shares,
        'pricePerShare': pricePerShare,
        'date': date.toIso8601String(),
      };

  factory StockPurchase.fromJson(Map<String, dynamic> json) => StockPurchase(
        shares: (json['shares'] as num).toDouble(),
        pricePerShare: (json['pricePerShare'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
      );
}
