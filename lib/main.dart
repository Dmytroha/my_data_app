import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Импортируем пакет http
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // <-- Импортируем для kIsWeb

// Модель данных (остается без изменений)
class Stock {
  final String symbol;
  final double price;
  final DateTime timestamp;

  Stock({required this.symbol, required this.price, required this.timestamp});

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol'] as String,
      price: (json['price'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Ticker',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const StockListScreen(),
    );
  }
}

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

// ... классы Stock, MyApp и StockListScreen остаются без изменений ...

class _StockListScreenState extends State<StockListScreen> {
  bool _isLoading = true;
  String? _error;
  List<Stock> _stocks = [];

  // ✅ ИСПРАВЛЕННАЯ ЛОГИКА ОПРЕДЕЛЕНИЯ URL
  // Константа kIsWeb определяет, запущено ли приложение в браузере.
  // Для веба мы всегда используем localhost.
  final String _url = kIsWeb
      ? 'http://localhost:8080/api/stock/data'
      : 'http://10.0.2.2:8080/api/stock/data'; // 10.0.2.2 остаётся для Android эмулятора

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Остальная часть метода _fetchData() остается без изменений...
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await http.get(Uri.parse(_url));

      if (response.statusCode == 200) {
        final List<dynamic> parsedList = jsonDecode(response.body);
        final List<Stock> loadedStocks = parsedList
            .map((item) => Stock.fromJson(item))
            .where((stock) => !stock.symbol.contains("Call Number"))
            .toList();

        setState(() {
          _stocks = loadedStocks;
          _isLoading = false;
        });
      } else {
        throw Exception(
          'Failed to load stock data (Status code: ${response.statusCode})',
        );
      }
    } catch (e) {
      // Важно: в браузере вы, скорее всего, увидите ошибку CORS
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Виджеты _buildBody() и build() остаются без изменений
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ошибка загрузки данных:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchData,
                child: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        // ... остальной код ListView.builder
        itemCount: _stocks.length,
        itemBuilder: (context, index) {
          final stock = _stocks[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  stock.symbol.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                stock.symbol,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                'Updated: ${DateFormat('yyyy-MM-dd – kk:mm:ss').format(stock.timestamp)}',
                style: TextStyle(color: Colors.grey[400]),
              ),
              trailing: Text(
                '\$${stock.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.lightGreenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Prices')),
      body: _buildBody(),
    );
  }
}
