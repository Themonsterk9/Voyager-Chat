import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const String _envBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    if (!kReleaseMode && kIsWeb && kDebugMode) {
      return 'http://localhost:3000';
    }
    if (!kReleaseMode && !kIsWeb && Platform.isAndroid && kDebugMode) {
      return 'http://10.0.2.2:3000';
    }
    if (!kReleaseMode && kDebugMode) {
      return 'http://127.0.0.1:3000';
    }
    return 'https://api.voyager.chat';
  }

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );
}
