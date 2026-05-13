import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyProvider extends ChangeNotifier {
  String _code = 'USD';
  Map<String, double> _rates = {
    'USD': 1.0,
    'CAD': 1.0,
    'EUR': 1.0,
    'GBP': 1.0,
  };

  static const _prefsKey = 'currency_code';
  static const currencies = ['USD', 'CAD', 'EUR', 'GBP'];
  static const _symbols = {
    'USD': '\$',
    'CAD': 'CA\$',
    'EUR': '€',
    'GBP': '£',
  };
  static const _names = {
    'USD': 'US Dollar',
    'CAD': 'Canadian Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
  };

  String get code => _code;
  String get symbol => _symbols[_code] ?? '\$';
  String nameOf(String code) => _names[code] ?? code;

  CurrencyProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _code = prefs.getString(_prefsKey) ?? 'USD';
    notifyListeners();
    await fetchRates();
  }

  Future<void> setCurrency(String code) async {
    if (!currencies.contains(code)) return;
    _code = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }

  Future<void> fetchRates() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://api.frankfurter.app/latest?from=USD&to=CAD,EUR,GBP'),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final r = data['rates'] as Map<String, dynamic>;
        _rates = {
          'USD': 1.0,
          'CAD': (r['CAD'] as num).toDouble(),
          'EUR': (r['EUR'] as num).toDouble(),
          'GBP': (r['GBP'] as num).toDouble(),
        };
        notifyListeners();
      }
    } catch (_) {
      // keep fallback 1:1 rates
    }
  }

  double convert(double usdAmount) => usdAmount * (_rates[_code] ?? 1.0);

  String format(double usdAmount) =>
      NumberFormat.currency(symbol: symbol, decimalDigits: 2)
          .format(convert(usdAmount));
}
