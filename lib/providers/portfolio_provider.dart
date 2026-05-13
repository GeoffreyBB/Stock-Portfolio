import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/portfolio_item.dart';
import '../models/price_alert.dart';
import '../models/stock_purchase.dart';
import '../models/stock_sale.dart';
import '../services/notification_service.dart';
import '../services/stock_api_service.dart';

enum PortfolioSort { value, alphabetical, shares, price }

class PortfolioProvider extends ChangeNotifier {
  final StockApiService _apiService = StockApiService();
  List<PortfolioItem> _items = [];
  List<StockSale> _sales = [];
  Map<String, double> _snapshots = {}; // "YYYY-MM-DD" → portfolio value
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  PortfolioSort _sort = PortfolioSort.value;

  static const _refreshInterval = Duration(seconds: 30);

  PortfolioSort get sort => _sort;

  void setSort(PortfolioSort s) {
    _sort = s;
    notifyListeners();
  }

  List<PortfolioItem> get items {
    final sorted = List<PortfolioItem>.from(_items);
    switch (_sort) {
      case PortfolioSort.value:
        sorted.sort((a, b) => b.currentValue.compareTo(a.currentValue));
      case PortfolioSort.alphabetical:
        sorted.sort((a, b) => a.symbol.compareTo(b.symbol));
      case PortfolioSort.shares:
        sorted.sort((a, b) => b.shares.compareTo(a.shares));
      case PortfolioSort.price:
        sorted.sort((a, b) =>
            (b.stock?.currentPrice ?? 0).compareTo(a.stock?.currentPrice ?? 0));
    }
    return List.unmodifiable(sorted);
  }
  List<StockSale> get sales => List.unmodifiable(_sales);
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalValue => _items.fold(0, (s, i) => s + i.currentValue);
  double get totalCost => _items.fold(0, (s, i) => s + i.costBasis);
  double get totalGainLoss => totalValue - totalCost;
  double get totalGainLossPercent =>
      totalCost > 0 ? (totalGainLoss / totalCost) * 100 : 0;
  double get totalDividendsReceived =>
      _items.fold(0, (s, i) => s + i.dividendsReceived);
  double get totalEstimatedAnnualIncome =>
      _items.fold(0, (s, i) => s + i.estimatedAnnualIncome);
  double get totalRealizedGains =>
      _sales.fold(0, (s, sale) => s + sale.realizedGain);
  double get totalDayChange =>
      _items.fold(0, (s, i) => s + (i.stock?.change ?? 0) * i.shares);

  List<StockSale> salesForSymbol(String symbol) =>
      _sales.where((s) => s.symbol == symbol.toUpperCase()).toList();

  /// Sorted list of (date, value) pairs for the portfolio chart.
  List<(DateTime, double)> get snapshotHistory {
    final entries = _snapshots.entries
        .map((e) => (DateTime.parse(e.key), e.value))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    return entries;
  }

  PortfolioProvider() {
    _load();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString('portfolio');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _items = list
          .map((e) => PortfolioItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final salesRaw = prefs.getString('sales');
    if (salesRaw != null) {
      final list = jsonDecode(salesRaw) as List;
      _sales = list
          .map((e) => StockSale.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final snapRaw = prefs.getString('snapshots');
    if (snapRaw != null) {
      final map = jsonDecode(snapRaw) as Map<String, dynamic>;
      _snapshots = map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    if (_items.isNotEmpty) notifyListeners();
    await refresh();
    _fetchMetrics();
    _calculateAllDividends();
    _startTimer();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'portfolio', jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  Future<void> _saveSales() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'sales', jsonEncode(_sales.map((s) => s.toJson()).toList()));
  }

  Future<void> _saveSnapshot() async {
    if (_items.isEmpty || totalValue == 0) return;
    final today =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    if (_snapshots.containsKey(today)) return;
    _snapshots[today] = totalValue;
    // Keep only last 90 days
    if (_snapshots.length > 90) {
      final sorted = _snapshots.keys.toList()..sort();
      _snapshots.remove(sorted.first);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('snapshots', jsonEncode(_snapshots));
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchMetrics() async {
    if (_items.isEmpty) return;
    final metrics =
        await _apiService.fetchAllMetrics(_items.map((i) => i.symbol).toList());
    for (final item in _items) {
      final m = metrics[item.symbol];
      if (m != null && item.stock != null) {
        item.stock = item.stock!.withMetrics(
          annualDividendPerShare: m.annualDividendPerShare,
          dividendYield: m.dividendYield,
        );
      }
    }
    notifyListeners();
  }

  Future<void> _fetchSparklines() async {
    if (_items.isEmpty) return;
    final sparklines = await _apiService
        .fetchAllSparklines(_items.map((i) => i.symbol).toList());
    for (final item in _items) {
      final data = sparklines[item.symbol];
      if (data != null && data.prices.isNotEmpty && item.stock != null) {
        item.stock = item.stock!.withSparkline(data.prices, data.dates);
      }
    }
    notifyListeners();
  }

  Future<void> _calculateAllDividends() async {
    if (_items.isEmpty) return;
    await Future.wait(_items.map((item) async {
      final earliest = item.earliestPurchaseDate;
      if (earliest == null) return;
      final dividends = await _apiService.fetchDividends(item.symbol, earliest);
      double total = 0;
      for (final div in dividends) {
        final sharesOnExDate = item.purchases
            .where((p) => !p.date.isAfter(div.exDate))
            .fold(0.0, (s, p) => s + p.shares);
        total += sharesOnExDate * div.amount;
      }
      item.dividendsReceived = total;
    }));
    notifyListeners();
    await _save();
  }

  Future<void> _checkAlerts() async {
    bool changed = false;
    for (final item in _items) {
      final price = item.stock?.currentPrice;
      if (price == null || item.alerts.isEmpty) continue;
      final triggered = item.alerts.where((a) => a.isTriggered(price)).toList();
      for (final alert in triggered) {
        await NotificationService.showPriceAlert(
            item.symbol, alert.notificationBody(item.symbol, price));
        item.alerts.remove(alert);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> refresh() async {
    if (_items.isEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final quotes =
        await _apiService.fetchQuotes(_items.map((i) => i.symbol).toList());
    if (quotes.isEmpty && _items.isNotEmpty) {
      _error = 'Could not fetch prices. Check your API key or connection.';
    }
    for (final item in _items) {
      final newStock = quotes[item.symbol];
      if (newStock != null && item.stock != null) {
        item.stock = newStock.withMetrics(
          annualDividendPerShare: item.stock!.annualDividendPerShare,
          dividendYield: item.stock!.dividendYield,
        ).withSparkline(item.stock!.sparklineData, item.stock!.sparklineDates);
      } else {
        item.stock = newStock;
      }
    }

    _isLoading = false;
    notifyListeners();

    _checkAlerts();
    _saveSnapshot();
    _fetchSparklines();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<bool> addItem(
      String symbol, double shares, double pricePerShare, DateTime date) async {
    final upper = symbol.toUpperCase();
    final stock = await _apiService.fetchQuote(upper);
    if (stock == null) return false;

    final existing = _items.indexWhere((i) => i.symbol == upper);
    if (existing != -1) {
      _items[existing].purchases.add(StockPurchase(
          shares: shares, pricePerShare: pricePerShare, date: date));
      _items[existing].stock = stock.withMetrics(
        annualDividendPerShare:
            _items[existing].stock?.annualDividendPerShare ?? 0,
        dividendYield: _items[existing].stock?.dividendYield ?? 0,
      ).withSparkline(
          _items[existing].stock?.sparklineData ?? [],
          _items[existing].stock?.sparklineDates ?? [],
        );
    } else {
      _items.add(PortfolioItem(
        symbol: upper,
        purchases: [
          StockPurchase(shares: shares, pricePerShare: pricePerShare, date: date)
        ],
      )..stock = stock);
    }
    notifyListeners();
    await _save();
    _fetchMetrics();
    _fetchSparklines();
    _calculateAllDividends();
    return true;
  }

  Future<void> removeItem(String symbol) async {
    _items.removeWhere((i) => i.symbol == symbol.toUpperCase());
    notifyListeners();
    await _save();
  }

  /// Sells [sharesToSell] shares using FIFO lot removal.
  Future<void> sell(String symbol, double sharesToSell, double salePrice,
      DateTime saleDate) async {
    final upper = symbol.toUpperCase();
    final idx = _items.indexWhere((i) => i.symbol == upper);
    if (idx == -1) return;

    final item = _items[idx];
    final costBasisPerShare = item.avgCost;

    _sales.add(StockSale(
      symbol: upper,
      shares: sharesToSell,
      salePrice: salePrice,
      saleDate: saleDate,
      costBasisPerShare: costBasisPerShare,
    ));

    // FIFO lot removal
    final lots = [...item.sortedPurchases];
    var remaining = sharesToSell;
    final updated = <StockPurchase>[];
    for (final lot in lots) {
      if (remaining <= 0) {
        updated.add(lot);
      } else if (lot.shares <= remaining) {
        remaining -= lot.shares;
      } else {
        updated.add(StockPurchase(
          shares: lot.shares - remaining,
          pricePerShare: lot.pricePerShare,
          date: lot.date,
        ));
        remaining = 0;
      }
    }

    if (updated.isEmpty) {
      _items.removeAt(idx);
    } else {
      _items[idx] = PortfolioItem(
        symbol: upper,
        purchases: updated,
        dividendsReceived: item.dividendsReceived,
        alerts: List.of(item.alerts),
      )..stock = item.stock;
    }

    notifyListeners();
    await _save();
    await _saveSales();
  }

  Future<void> addAlert(String symbol, PriceAlert alert) async {
    final idx = _items.indexWhere((i) => i.symbol == symbol.toUpperCase());
    if (idx == -1) return;
    _items[idx].alerts.add(alert);
    notifyListeners();
    await _save();
  }

  Future<void> removeAlert(String symbol, String alertId) async {
    final idx = _items.indexWhere((i) => i.symbol == symbol.toUpperCase());
    if (idx == -1) return;
    _items[idx].alerts.removeWhere((a) => a.id == alertId);
    notifyListeners();
    await _save();
  }
}
