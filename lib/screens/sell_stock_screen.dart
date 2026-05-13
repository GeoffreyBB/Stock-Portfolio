import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/portfolio_provider.dart';

class SellStockScreen extends StatefulWidget {
  final String symbol;
  const SellStockScreen({super.key, required this.symbol});

  @override
  State<SellStockScreen> createState() => _SellStockScreenState();
}

class _SellStockScreenState extends State<SellStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sharesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  DateTime _saleDate = DateTime.now();
  bool _loading = false;

  static final _dateFmt = DateFormat('MMMM d, y');

  @override
  void initState() {
    super.initState();
    final item = context
        .read<PortfolioProvider>()
        .items
        .firstWhere((i) => i.symbol == widget.symbol);
    if (item.stock != null) {
      _priceCtrl.text = item.stock!.currentPrice.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _sharesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _saleDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    await context.read<PortfolioProvider>().sell(
          widget.symbol,
          double.parse(_sharesCtrl.text.trim()),
          double.parse(_priceCtrl.text.trim()),
          _saleDate,
        );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final item = context
        .read<PortfolioProvider>()
        .items
        .firstWhere((i) => i.symbol == widget.symbol);
    final maxShares = item.shares;

    return Scaffold(
      appBar: AppBar(title: Text('Sell ${widget.symbol}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _sharesCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Shares to Sell',
                  hintText: 'Max: ${maxShares % 1 == 0 ? maxShares.toInt() : maxShares}',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a valid number of shares';
                  if (n > maxShares) return 'You only own ${maxShares % 1 == 0 ? maxShares.toInt() : maxShares} shares';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Sale Price Per Share (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Sale Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(_dateFmt.format(_saleDate)),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm Sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
