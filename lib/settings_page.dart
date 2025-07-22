import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

// --- Класс для модели данных настроек ---
// Этот класс описывает структуру JSON, которую мы ожидаем от бэкенда для настроек.
class AppSettings {
  final int refreshIntervalSeconds;
  final double temperatureThreshold;
  final bool humidityAlertEnabled;

  AppSettings({
    required this.refreshIntervalSeconds,
    required this.temperatureThreshold,
    required this.humidityAlertEnabled,
  });

  // Фабричный конструктор для создания AppSettings из Map (JSON-объекта)
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      refreshIntervalSeconds: json['refreshIntervalSeconds'] as int,
      temperatureThreshold: (json['temperatureThreshold'] as num)
          .toDouble(), // num для int или double
      humidityAlertEnabled: json['humidityAlertEnabled'] as bool,
    );
  }

  // Метод для преобразования объекта AppSettings обратно в Map (удобно для отладки)
  Map<String, dynamic> toJson() {
    return {
      'refreshIntervalSeconds': refreshIntervalSeconds,
      'temperatureThreshold': temperatureThreshold,
      'humidityAlertEnabled': humidityAlertEnabled,
    };
  }
}

// --- Страница настроек ---
// Это новый StatefulWidget, который будет отображать настройки.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings? _appSettings; // Здесь будут храниться загруженные настройки
  bool _isLoading = true; // Флаг состояния загрузки
  String _errorMessage = ''; // Сообщение об ошибке, если что-то пошло не так

  @override
  void initState() {
    super.initState();
    _fetchSettings(); // Загружаем настройки при инициализации страницы
  }

  // Асинхронная функция для получения настроек с бэкенда
  Future<void> _fetchSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _appSettings = null;
    });

    try {
      // *** ВАЖНО: ЗАМЕНИ ЭТУ ССЫЛКУ НА АДРЕС ТВОЕГО БЭКЕНДА ДЛЯ НАСТРОЕК ***
      // Создай новый mock на Mockachino, который будет возвращать JSON в формате AppSettings.
      // Пример URL будет выглядеть так: https://www.mockachino.com/ТВОЙ_ID_ПРОЕКТА/settings
      // Замени 'ТВОЙ_ID_ПРОЕКТА' на реальный ID твоего проекта на Mockachino.
      final response = await http.get(
        Uri.parse(dotenv.env['BASE_API_URL_SETTINGS']!),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        setState(() {
          _appSettings = AppSettings.fromJson(jsonData);
        });
      } else {
        setState(() {
          _errorMessage =
              'Ошибка при загрузке настроек: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка сети или парсинга настроек: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), // Кнопка "Обновить" для настроек
            onPressed: _fetchSettings,
          ),
        ],
      ),
      body: _buildBody(), // Логика отображения тела вынесена в отдельный метод
    );
  }

  // Вспомогательный метод для построения тела страницы настроек
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
                onPressed: _fetchSettings,
                child: const Text('Повторить загрузку настроек'),
              ),
            ],
          ),
        ),
      );
    } else if (_appSettings == null) {
      return const Center(
        child: Text('Настройки не загружены. Пожалуйста, попробуйте обновить.'),
      );
    } else {
      // Если настройки успешно загружены, отображаем их в виде карточек
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingCard(
              title: 'Интервал обновления данных',
              value: '${_appSettings!.refreshIntervalSeconds} секунд',
              icon: Icons.timer,
            ),
            _buildSettingCard(
              title: 'Порог температуры',
              value: '${_appSettings!.temperatureThreshold}°C',
              icon: Icons.thermostat_outlined,
            ),
            _buildSettingCard(
              title: 'Уведомления о влажности',
              value: _appSettings!.humidityAlertEnabled
                  ? 'Включены'
                  : 'Выключены',
              icon: _appSettings!.humidityAlertEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
            ),
            const SizedBox(height: 20),
            const Text(
              'Сырые данные настроек (для отладки):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            // Отображаем сырые данные JSON (для отладки)
            Text(
              json.encode(_appSettings!.toJson()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  // Вспомогательный метод для создания унифицированных карточек настроек
  Widget _buildSettingCard({
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
