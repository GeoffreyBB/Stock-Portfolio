class StockSale {
  final String symbol;
  final double shares;
  final double salePrice;
  final DateTime saleDate;
  final double costBasisPerShare;

  const StockSale({
    required this.symbol,
    required this.shares,
    required this.salePrice,
    required this.saleDate,
    required this.costBasisPerShare,
  });

  double get proceeds => shares * salePrice;
  double get cost => shares * costBasisPerShare;
  double get realizedGain => proceeds - cost;
  double get realizedGainPercent => cost > 0 ? (realizedGain / cost) * 100 : 0;

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'shares': shares,
        'salePrice': salePrice,
        'saleDate': saleDate.toIso8601String(),
        'costBasisPerShare': costBasisPerShare,
      };

  factory StockSale.fromJson(Map<String, dynamic> json) => StockSale(
        symbol: json['symbol'] as String,
        shares: (json['shares'] as num).toDouble(),
        salePrice: (json['salePrice'] as num).toDouble(),
        saleDate: DateTime.parse(json['saleDate'] as String),
        costBasisPerShare: (json['costBasisPerShare'] as num).toDouble(),
      );
}
