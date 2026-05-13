import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/price_alert.dart';
import '../models/watchlist_item.dart';
import '../services/notification_service.dart';
import '../services/stock_api_service.dart';

class WatchlistProvider extends ChangeNotifier {
  final StockApiService _apiService = StockApiService();
  List<WatchlistItem> _items = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  static const _refreshInterval = Duration(seconds: 30);

  List<WatchlistItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  WatchlistProvider() {
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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('watchlist');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _items =
          list.map((e) => WatchlistItem.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
      await refresh();
    }
    _startTimer();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'watchlist', jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  Future<void> refresh() async {
    if (_items.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    final quotes =
        await _apiService.fetchQuotes(_items.map((i) => i.symbol).toList());
    for (final item in _items) {
      item.stock = quotes[item.symbol];
    }
    _isLoading = false;
    notifyListeners();
    _checkAlerts();
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

  Future<bool> addItem(String symbol) async {
    final upper = symbol.toUpperCase();
    if (_items.any((i) => i.symbol == upper)) return false;
    final stock = await _apiService.fetchQuote(upper);
    if (stock == null) return false;
    _items.add(WatchlistItem(symbol: upper, stock: stock));
    await _save();
    notifyListeners();
    return true;
  }

  void removeItem(String symbol) {
    _items.removeWhere((i) => i.symbol == symbol.toUpperCase());
    notifyListeners();
    _save();
  }
}
