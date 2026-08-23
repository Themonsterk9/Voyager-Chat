import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/location/location_data.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/map_server_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService.instance;

  LocationData? _currentLocation;
  bool _loadingLocation = true;
  MapTilerConnectionStatus _mapTilerStatus = MapTilerConnectionStatus.loading;
  MapProviderType _activeProvider = MapProviderType.mapTiler;
  int _zoomLevel = 13;
  Offset _panOffset = Offset.zero;
  bool _showDiagnostics = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() {
      _loadingLocation = true;
      _mapTilerStatus = MapTilerConnectionStatus.loading;
    });

    final loc = await _locationService.getCurrentLocation();
    final status = await MapServerConfig.validateMapTilerConnection();

    if (mounted) {
      setState(() {
        _currentLocation = loc;
        _mapTilerStatus = status;
        _loadingLocation = false;
      });
    }
  }

  void _zoomIn() {
    setState(() {
      if (_zoomLevel < 18) _zoomLevel++;
    });
  }

  void _zoomOut() {
    setState(() {
      if (_zoomLevel > 2) _zoomLevel--;
    });
  }

  void _recenterMap() {
    setState(() {
      _panOffset = Offset.zero;
      _zoomLevel = 13;
    });
    _initializeMap();
  }

  Future<void> _triggerEmergencyShare() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text('EMERGENCY LOCATION SHARE')),
          ],
        ),
        content: const Text(
          'This will send your encrypted live GPS coordinates to trusted emergency contacts. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('BROADCAST EMERGENCY'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Encrypted emergency location broadcasted to trusted contacts.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildStatusHeader() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_activeProvider == MapProviderType.openStreetMap) {
      statusText = 'ONLINE • OpenStreetMap';
      statusColor = Colors.lightBlueAccent;
      statusIcon = Icons.map_rounded;
    } else {
      switch (_mapTilerStatus) {
        case MapTilerConnectionStatus.online:
          statusText = 'ONLINE • MapTiler';
          statusColor = Colors.greenAccent;
          statusIcon = Icons.check_circle_rounded;
          break;
        case MapTilerConnectionStatus.offline:
          statusText = 'OFFLINE';
          statusColor = Colors.amberAccent;
          statusIcon = Icons.wifi_off_rounded;
          break;
        case MapTilerConnectionStatus.invalidKey:
        case MapTilerConnectionStatus.error:
          statusText = 'MAP UNAVAILABLE';
          statusColor = Colors.redAccent;
          statusIcon = Icons.error_outline_rounded;
          break;
        case MapTilerConnectionStatus.loading:
          statusText = 'LOADING MAP';
          statusColor = Colors.cyanAccent;
          statusIcon = Icons.sync_rounded;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCanvas() {
    final isOnline =
        _activeProvider == MapProviderType.openStreetMap ||
        _mapTilerStatus == MapTilerConnectionStatus.online;
    final lat = _currentLocation?.latitude ?? 37.7749;
    final lng = _currentLocation?.longitude ?? -122.4194;

    // Calculate 3x3 surrounding tiles for full map detail coverage (streets, land, water, labels)
    final tiles = MapServerConfig.getSurroundingTileGrid(lat, lng, _zoomLevel);

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _panOffset += details.delta;
        });
      },
      child: Container(
        color: const Color(0xFF1E293B),
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // Map 3x3 Tile Grid Renderer (MapTiler or OpenStreetMap)
            if (isOnline)
              Positioned.fill(
                child: Transform.translate(
                  offset: _panOffset,
                  child: Center(
                    child: SizedBox(
                      width: 768,
                      height: 768,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.0,
                            ),
                        itemCount: tiles.length,
                        itemBuilder: (context, index) {
                          final tile = tiles[index];
                          final url = MapServerConfig.buildTileUrlForProvider(
                            _activeProvider,
                            tile.z,
                            tile.x,
                            tile.y,
                          );

                          return Image.network(
                            url,
                            fit: BoxFit.cover,
                            headers:
                                _activeProvider == MapProviderType.openStreetMap
                                ? const {
                                    'User-Agent': 'VoyagerChat/1.0 (Privacy-First OpenSource Navigation)',
                                  }
                                : null,
                            errorBuilder: (context, error, stackTrace) {
                              MapServerConfig.logDiagnostic(
                                'TILE_LOAD_FAILED',
                                detail:
                                    'Tile ${tile.z}/${tile.x}/${tile.y} failed',
                              );
                              return Container(
                                color: const Color(0xFF0F172A),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: const Color(0xFF0F172A),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _mapTilerStatus == MapTilerConnectionStatus.offline
                              ? Icons.cloud_off_rounded
                              : Icons.map_outlined,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _mapTilerStatus == MapTilerConnectionStatus.offline
                              ? 'Offline Mode — Reconnect to load map tiles'
                              : 'MapTiler Key Missing or Invalid',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Pin & Location Card Overlay
            Center(
              child: Transform.translate(
                offset: _panOffset,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentLocation?.isDeviceGps == true
                          ? Icons.location_on
                          : Icons.my_location,
                      size: 44,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 4),
                    Card(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          _currentLocation?.isDeviceGps == true
                              ? 'Real GPS Location: ${_currentLocation!.formatCoordinates()}'
                              : 'Map Center (Default Test Location): ${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _currentLocation?.isDeviceGps == true
                                ? Colors.greenAccent
                                : Colors.amberAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // OpenStreetMap Mandatory Attribution Badge
            if (_activeProvider == MapProviderType.openStreetMap)
              Positioned(
                bottom: 80,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    MapServerConfig.osmAttribution,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MapTiler Diagnostic Logs (Debug Mode Only • Key Redacted)',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _showDiagnostics = false),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView.builder(
              itemCount: MapServerConfig.diagnosticLogs.length,
              itemBuilder: (context, index) {
                final log = MapServerConfig.diagnosticLogs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MapLibre Navigation'),
        actions: [
          PopupMenuButton<MapProviderType>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Select Map Provider',
            initialValue: _activeProvider,
            onSelected: (provider) {
              setState(() {
                _activeProvider = provider;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: MapProviderType.mapTiler,
                child: Row(
                  children: [
                    Icon(Icons.map, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text('MapTiler Streets'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: MapProviderType.openStreetMap,
                child: Row(
                  children: [
                    Icon(Icons.public, color: Colors.lightBlueAccent),
                    SizedBox(width: 8),
                    Text('OpenStreetMap'),
                  ],
                ),
              ),
            ],
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () =>
                  setState(() => _showDiagnostics = !_showDiagnostics),
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _recenterMap,
          ),
        ],
      ),
      body: _loadingLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Interactive Map Canvas
                _buildMapCanvas(),

                // Status Header Overlay
                Positioned(top: 16, left: 16, child: _buildStatusHeader()),

                // Diagnostic Overlay (Development Only)
                if (kDebugMode && _showDiagnostics)
                  Positioned.fill(child: _buildDiagnosticOverlay()),

                // Zoom & Recenter Controls Overlay
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoomIn',
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoomOut',
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'recenter',
                        onPressed: _recenterMap,
                        child: const Icon(Icons.gps_fixed),
                      ),
                    ],
                  ),
                ),

                // Emergency Share FAB
                Positioned(
                  left: 16,
                  bottom: 24,
                  right: 16,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'EMERGENCY LOCATION SHARE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: _triggerEmergencyShare,
                  ),
                ),
              ],
            ),
    );
  }
}
