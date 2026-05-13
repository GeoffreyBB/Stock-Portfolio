import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock.dart';

class StockApiService {
  static const String _apiKey = 'd81seo1r01qrojfd1dogd81seo1r01qrojfd1dp0';
  static const String _baseUrl = 'https://finnhub.io/api/v1';
  static const _yahooHeaders = {'User-Agent': 'Mozilla/5.0'};

  Future<Stock?> fetchQuote(String symbol) async {
    try {
      final uri = Uri.parse('$_baseUrl/quote?symbol=$symbol&token=$_apiKey');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if ((data['c'] as num?)?.toDouble() == 0) return null;
        return Stock.fromJson(symbol.toUpperCase(), data);
      }
    } catch (_) {}
    return null;
  }

  Future<({double annualDividendPerShare, double dividendYield})> fetchMetrics(
      String symbol) async {
    try {
      final uri = Uri.parse(
          '$_baseUrl/stock/metric?symbol=$symbol&metric=all&token=$_apiKey');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final metric = data['metric'] as Map<String, dynamic>?;
        if (metric != null) {
          final div =
              (metric['dividendPerShareAnnual'] as num?)?.toDouble() ?? 0;
          final yield_ =
              (metric['dividendYieldIndicatedAnnual'] as num?)?.toDouble() ?? 0;
          return (annualDividendPerShare: div, dividendYield: yield_);
        }
      }
    } catch (_) {}
    return (annualDividendPerShare: 0.0, dividendYield: 0.0);
  }

  // Uses Yahoo Finance — Finnhub dividend history requires a paid plan.
  Future<List<({DateTime exDate, double amount})>> fetchDividends(
      String symbol, DateTime from) async {
    try {
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol'
          '?events=dividends&range=max&interval=1mo');
      final response = await http.get(uri, headers: _yahooHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = (data['chart']['result'] as List?)?.first
            as Map<String, dynamic>?;
        final divMap =
            (result?['events'] as Map<String, dynamic>?)?['dividends']
                as Map<String, dynamic>?;
        if (divMap == null) return [];

        final now = DateTime.now();
        return divMap.values
            .map((e) {
              final map = e as Map<String, dynamic>;
              final exDate = DateTime.fromMillisecondsSinceEpoch(
                  (map['date'] as int) * 1000);
              return (exDate: exDate, amount: (map['amount'] as num).toDouble());
            })
            .where((d) => !d.exDate.isBefore(from) && !d.exDate.isAfter(now))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<({List<double> prices, List<DateTime> dates})> fetchSparkline(
      String symbol) async {
    try {
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol'
          '?range=3mo&interval=1d');
      final response = await http.get(uri, headers: _yahooHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = (data['chart']['result'] as List?)?.first
            as Map<String, dynamic>?;
        final rawTimestamps = result?['timestamp'] as List?;
        final rawCloses =
            result?['indicators']?['quote']?[0]?['close'] as List?;
        if (rawTimestamps == null || rawCloses == null) {
          return (prices: <double>[], dates: <DateTime>[]);
        }
        final prices = <double>[];
        final dates = <DateTime>[];
        for (var i = 0; i < rawTimestamps.length; i++) {
          final close = i < rawCloses.length ? rawCloses[i] : null;
          if (close == null) continue;
          prices.add((close as num).toDouble());
          dates.add(DateTime.fromMillisecondsSinceEpoch(
              (rawTimestamps[i] as int) * 1000));
        }
        return (prices: prices, dates: dates);
      }
    } catch (_) {}
    return (prices: <double>[], dates: <DateTime>[]);
  }

  Future<Map<String, Stock>> fetchQuotes(List<String> symbols) async {
    final results = <String, Stock>{};
    await Future.wait(symbols.map((s) async {
      final stock = await fetchQuote(s);
      if (stock != null) results[s.toUpperCase()] = stock;
    }));
    return results;
  }

  Future<Map<String, ({double annualDividendPerShare, double dividendYield})>>
      fetchAllMetrics(List<String> symbols) async {
    final results =
        <String, ({double annualDividendPerShare, double dividendYield})>{};
    await Future.wait(symbols.map((s) async {
      results[s.toUpperCase()] = await fetchMetrics(s);
    }));
    return results;
  }

  Future<Map<String, ({List<double> prices, List<DateTime> dates})>>
      fetchAllSparklines(List<String> symbols) async {
    final results =
        <String, ({List<double> prices, List<DateTime> dates})>{};
    await Future.wait(symbols.map((s) async {
      results[s.toUpperCase()] = await fetchSparkline(s);
    }));
    return results;
  }
}
