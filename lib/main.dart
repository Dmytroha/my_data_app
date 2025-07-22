import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:my_data_app/settings_page.dart'; // Импортируем страницу настроек
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async'; // Для работы с таймерами

// Загружаем .env файл перед запуском приложения
Future<void> main() async {
  // main должен быть асинхронным
  await dotenv.load(fileName: ".env"); // Загружаем переменные из .env
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мое Приложение для Данных',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

// --- Классы для модели данных (SensorData и Reading - без изменений) ---
class Reading {
  final String time;
  final double value;

  Reading({required this.time, required this.value});

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      time: json['time'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

class SensorData {
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final String status;
  final List<Reading> readings;

  SensorData({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.status,
    required this.readings,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> readingsJson = json['readings'] as List<dynamic>;
    final List<Reading> readingsList = readingsJson
        .map((e) => Reading.fromJson(e as Map<String, dynamic>))
        .toList();

    return SensorData(
      timestamp: DateTime.parse(json['timestamp'] as String),
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      status: json['status'] as String,
      readings: readingsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'humidity': humidity,
      'status': status,
      'readings': readings
          .map((e) => {'time': e.time, 'value': e.value})
          .toList(),
    };
  }
}

// --- HomePage Widget ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SensorData? _sensorData;
  AppSettings? _appSettings; // Добавляем переменную для хранения настроек
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _timer; // Объявляем таймер

  @override
  void initState() {
    super.initState();
    _fetchCombinedData(); // Загружаем и данные, и настройки
  }

  @override
  void dispose() {
    _timer?.cancel(); // Очень важно: отменяем таймер при уничтожении виджета
    super.dispose();
  }

  // Новая функция для загрузки как данных, так и настроек
  Future<void> _fetchCombinedData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _sensorData = null;
      _timer?.cancel(); // Отменяем старый таймер перед новой загрузкой
    });

    try {
      // 1. Загружаем основные данные (сенсоры)
      final dataResponse = await http.get(
        Uri.parse(dotenv.env['BASE_API_URL_DATA']!),
      );
      // 2. Загружаем настройки
      // ТВОЙ URL НАСТРОЕК (как ты его настроил на Mockachino)
      final settingsResponse = await http.get(
        Uri.parse(dotenv.env['BASE_API_URL_SETTINGS']!),
      );

      if (dataResponse.statusCode == 200 &&
          settingsResponse.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(dataResponse.body);
        final Map<String, dynamic> jsonSettings = json.decode(
          settingsResponse.body,
        );

        setState(() {
          _sensorData = SensorData.fromJson(jsonData);
          _appSettings = AppSettings.fromJson(jsonSettings);
        });
        _startAutoRefreshTimer(); // Запускаем таймер после успешной загрузки настроек
      } else {
        // Обработка ошибок для обоих запросов
        String dataError = dataResponse.statusCode != 200
            ? 'Ошибка данных: ${dataResponse.statusCode}'
            : '';
        String settingsError = settingsResponse.statusCode != 200
            ? 'Ошибка настроек: ${settingsResponse.statusCode}'
            : '';
        setState(() {
          _errorMessage = 'Проблемы при загрузке: $dataError $settingsError'
              .trim();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка сети или парсинга: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Функция для запуска таймера
  void _startAutoRefreshTimer() {
    _timer?.cancel(); // Убедимся, что предыдущий таймер отменен
    if (_appSettings != null && _appSettings!.refreshIntervalSeconds > 0) {
      _timer = Timer.periodic(
        Duration(seconds: _appSettings!.refreshIntervalSeconds),
        (Timer t) =>
            _fetchDataOnly(), // Вызываем функцию для получения только данных
      );
    }
  }

  // Отдельная функция для получения ТОЛЬКО данных (для автообновления)
  Future<void> _fetchDataOnly() async {
    try {
      // ТВОЙ URL ДАННЫХ (как ты его настроил на Mockachino)
      final response = await http.get(
        Uri.parse(dotenv.env['BASE_API_URL_DATA']!),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        setState(() {
          _sensorData = SensorData.fromJson(jsonData);
        });
      } else {
        // Можно вывести сообщение об ошибке в консоль или в UI
        print('Ошибка автообновления данных: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка сети при автообновлении: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Данные с Бэкенда'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                _fetchCombinedData, // Теперь эта кнопка перезагружает и данные, и настройки
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    _fetchCombinedData, // Повторная попытка загрузки всего
                child: const Text('Повторить загрузку'),
              ),
            ],
          ),
        ),
      );
    } else if (_sensorData == null || _appSettings == null) {
      return const Center(
        child: Text(
          'Данные или настройки не загружены. Пожалуйста, попробуйте обновить.',
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Последнее обновление: ${_sensorData!.timestamp.toLocal().toString().substring(0, 19)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            Text(
              'Автообновление: ${_appSettings!.refreshIntervalSeconds} сек.', // Показываем текущий интервал
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            _buildDataCard(
              title: 'Температура',
              value: '${_sensorData!.temperature}°C',
              icon: Icons.thermostat,
            ),
            _buildDataCard(
              title: 'Влажность',
              value: '${_sensorData!.humidity}%',
              icon: Icons.water_drop,
            ),
            _buildDataCard(
              title: 'Статус',
              value: _sensorData!.status,
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 20),
            const Text(
              'Показания по времени:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < _sensorData!.readings.length) {
                            return Text(
                              _sensorData!.readings[value.toInt()].time,
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 5,
                        getTitlesWidget: (value, meta) =>
                            Text('${value.toInt()}'),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: const Color(0xff37434d),
                      width: 1,
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _sensorData!.readings.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Сырые данные (для отладки):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              json.encode(_sensorData!.toJson()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Text(
              'Сырые настройки (для отладки):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              json.encode(_appSettings!.toJson()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDataCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 30),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(value, style: const TextStyle(fontSize: 20)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
