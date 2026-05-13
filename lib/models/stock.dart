class Stock {
  final String symbol;
  final double currentPrice;
  final double previousClose;
  final double change;
  final double percentChange;
  final double high;
  final double low;
  final double open;
  final double annualDividendPerShare;
  final double dividendYield;
  final List<double> sparklineData;
  final List<DateTime> sparklineDates;

  const Stock({
    required this.symbol,
    required this.currentPrice,
    required this.previousClose,
    required this.change,
    required this.percentChange,
    required this.high,
    required this.low,
    required this.open,
    this.annualDividendPerShare = 0,
    this.dividendYield = 0,
    this.sparklineData = const [],
    this.sparklineDates = const [],
  });

  factory Stock.fromJson(String symbol, Map<String, dynamic> json) {
    return Stock(
      symbol: symbol,
      currentPrice: (json['c'] as num).toDouble(),
      previousClose: (json['pc'] as num).toDouble(),
      change: (json['d'] as num).toDouble(),
      percentChange: (json['dp'] as num).toDouble(),
      high: (json['h'] as num).toDouble(),
      low: (json['l'] as num).toDouble(),
      open: (json['o'] as num).toDouble(),
    );
  }

  Stock withMetrics({required double annualDividendPerShare, required double dividendYield}) {
    return Stock(
      symbol: symbol,
      currentPrice: currentPrice,
      previousClose: previousClose,
      change: change,
      percentChange: percentChange,
      high: high,
      low: low,
      open: open,
      annualDividendPerShare: annualDividendPerShare,
      dividendYield: dividendYield,
      sparklineData: sparklineData,
      sparklineDates: sparklineDates,
    );
  }

  Stock withSparkline(List<double> data, [List<DateTime> dates = const []]) {
    return Stock(
      symbol: symbol,
      currentPrice: currentPrice,
      previousClose: previousClose,
      change: change,
      percentChange: percentChange,
      high: high,
      low: low,
      open: open,
      annualDividendPerShare: annualDividendPerShare,
      dividendYield: dividendYield,
      sparklineData: data,
      sparklineDates: dates,
    );
  }
}
