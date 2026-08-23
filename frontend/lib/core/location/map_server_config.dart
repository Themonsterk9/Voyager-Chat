import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

enum MapTilerConnectionStatus { loading, online, offline, invalidKey, error }

enum MapProviderType { mapTiler, openStreetMap }

class TileCoordinate {
  const TileCoordinate(this.x, this.y, this.z);

  final int x;
  final int y;
  final int z;

  @override
  String toString() => 'Tile($z, $x, $y)';
}

abstract final class MapServerConfig {
  static const String _defaultMapTilerKey = String.fromEnvironment(
    'MAPTILER_API_KEY',
    defaultValue: '',
  );

  static String _overrideKey = '';
  static String _envFileKey = '';
  static bool _hasTriedLoadEnv = false;

  static const String osmAttribution = '© OpenStreetMap contributors';

  static final List<String> diagnosticLogs = [];

  static void logDiagnostic(String event, {int? statusCode, String? detail}) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry =
        '[$timestamp] MAPTILER_DIAGNOSTIC: $event | Status: ${statusCode ?? "N/A"} | Detail: ${detail ?? "None"}';
    diagnosticLogs.add(logEntry);
    if (diagnosticLogs.length > 50) {
      diagnosticLogs.removeAt(0);
    }
  }

  static void setApiKey(String key) {
    _overrideKey = key;
  }

  static void _ensureEnvLoaded() {
    if (_hasTriedLoadEnv) return;
    _hasTriedLoadEnv = true;
    try {
      final file = File('.env');
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('MAPTILER_API_KEY=')) {
            _envFileKey = trimmed.substring('MAPTILER_API_KEY='.length).trim();
            break;
          }
        }
      }
    } catch (_) {}
  }

  static String get mapTilerApiKey {
    if (_overrideKey.isNotEmpty) return _overrideKey;
    if (_defaultMapTilerKey.isNotEmpty) return _defaultMapTilerKey;
    _ensureEnvLoaded();
    return _envFileKey;
  }

  static const String mapTilerStyle = String.fromEnvironment(
    'MAPTILER_STYLE',
    defaultValue: 'streets-v2',
  );

  static bool get hasValidKey => mapTilerApiKey.isNotEmpty;

  static String get vectorStyleUrl {
    final key = mapTilerApiKey;
    if (key.isEmpty) return 'https://demotiles.maplibre.org/style.json';
    return 'https://api.maptiler.com/maps/$mapTilerStyle/style.json?key=$key';
  }

  static String get rasterTileUrlTemplate {
    final key = mapTilerApiKey;
    if (key.isEmpty) {
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
    return 'https://api.maptiler.com/maps/$mapTilerStyle/256/{z}/{x}/{y}.png?key=$key';
  }

  static String buildTileUrl(int z, int x, int y) {
    return buildTileUrlForProvider(MapProviderType.mapTiler, z, x, y);
  }

  static String buildTileUrlForProvider(
    MapProviderType provider,
    int z,
    int x,
    int y,
  ) {
    if (provider == MapProviderType.openStreetMap) {
      return 'https://tile.openstreetmap.org/$z/$x/$y.png';
    }

    final key = mapTilerApiKey;
    if (key.isEmpty) {
      return 'https://tile.openstreetmap.org/$z/$x/$y.png';
    }
    return 'https://api.maptiler.com/maps/$mapTilerStyle/256/$z/$x/$y.png?key=$key';
  }

  static TileCoordinate latLngToTileXY(double lat, double lng, int zoom) {
    final latRad = lat * math.pi / 180.0;
    final n = math.pow(2, zoom).toDouble();
    final xtile = ((lng + 180.0) / 360.0 * n).floor();
    final ytile =
        ((1.0 -
                    math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) /
                        math.pi) /
                2.0 *
                n)
            .floor();
    return TileCoordinate(xtile, ytile, zoom);
  }

  static List<TileCoordinate> getSurroundingTileGrid(
    double lat,
    double lng,
    int zoom,
  ) {
    final center = latLngToTileXY(lat, lng, zoom);
    final maxTile = (math.pow(2, zoom) - 1).toInt();
    final tiles = <TileCoordinate>[];

    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final x = (center.x + dx).clamp(0, maxTile);
        final y = (center.y + dy).clamp(0, maxTile);
        tiles.add(TileCoordinate(x, y, zoom));
      }
    }
    return tiles;
  }

  static String get obfuscatedKey {
    final key = mapTilerApiKey;
    if (key.isEmpty) return 'NOT_SET';
    if (key.length <= 8) return '********';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }

  static Future<MapTilerConnectionStatus> validateMapTilerConnection({
    http.Client? client,
  }) async {
    final key = mapTilerApiKey;
    if (key.isEmpty) {
      logDiagnostic(
        'API_KEY_MISSING',
        detail: 'Key is empty or not configured in .env',
      );
      return MapTilerConnectionStatus.invalidKey;
    }

    final url = Uri.parse(
      'https://api.maptiler.com/maps/$mapTilerStyle/style.json?key=$key',
    );
    try {
      final httpClient = client ?? http.Client();
      final response = await httpClient
          .get(url)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        logDiagnostic(
          'CONNECT_SUCCESS',
          statusCode: 200,
          detail: 'MapTiler style loaded successfully',
        );
        return MapTilerConnectionStatus.online;
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        logDiagnostic(
          'AUTH_ERROR',
          statusCode: response.statusCode,
          detail: 'Invalid API key or origin restricted',
        );
        return MapTilerConnectionStatus.invalidKey;
      } else {
        logDiagnostic(
          'HTTP_ERROR',
          statusCode: response.statusCode,
          detail: 'Unexpected status from MapTiler API',
        );
        return MapTilerConnectionStatus.error;
      }
    } on SocketException catch (e) {
      logDiagnostic('OFFLINE', detail: 'SocketException: ${e.message}');
      return MapTilerConnectionStatus.offline;
    } on TimeoutException {
      logDiagnostic('TIMEOUT', detail: 'Connection timed out');
      return MapTilerConnectionStatus.offline;
    } catch (e) {
      logDiagnostic('UNKNOWN_ERROR', detail: e.toString());
      return MapTilerConnectionStatus.error;
    }
  }
}
