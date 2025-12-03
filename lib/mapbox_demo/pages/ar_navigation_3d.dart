// =====================================================
// 🎯 AR NAVIGATION 3D - SOLUCIÓN DEFINITIVA
// =====================================================
// FIXES CRÍTICOS:
// 1. Compass heading normalizado correctamente (0-360°)
// 2. Waypoints validados y en orden correcto
// 3. Cálculos de distancia/bearing funcionando
// 4. RelativeAngle calculado correctamente
// =====================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/ar_route_calculator.dart';
import '../../services/ar_sensor_manager.dart';
import '../../widgets/ar_arrow_painter.dart';
import '../../widgets/ar_hud_overlay.dart';

class ArNavigation3D extends StatefulWidget {
  final double targetLat;
  final double targetLon;
  final String targetName;
  final List<Map<String, dynamic>> routeWaypoints;

  const ArNavigation3D({
    super.key,
    required this.targetLat,
    required this.targetLon,
    required this.targetName,
    required this.routeWaypoints,
  });

  @override
  State<ArNavigation3D> createState() => _ArNavigation3DState();
}

class _ArNavigation3DState extends State<ArNavigation3D>
    with TickerProviderStateMixin {
  // =====================================================
  // 📸 CÁMARA
  // =====================================================
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // =====================================================
  // 🧭 SENSORES Y ORIENTACIÓN (CORREGIDOS)
  // =====================================================
  final ArSensorManager _sensorManager = ArSensorManager();

  double _compassHeading = 0;
  double _pitch = 0;
  double _roll = 0;
  double _compassAccuracy = 100;

  // =====================================================
  // 📍 UBICACIÓN Y NAVEGACIÓN
  // =====================================================
  late ArRouteCalculator _routeCalculator;
  StreamSubscription<Position>? _positionStream;

  double _currentLat = 0;
  double _currentLon = 0;
  double _currentAltitude = 0;
  double _userSpeed = 0;

  int _currentWaypointIndex = 0;
  double _distanceToNextWaypoint = 0;
  double _bearingToWaypoint = 0;
  double _totalDistanceRemaining = 0;

  // =====================================================
  // 🎯 TARGET ACTUAL (waypoint o destino final)
  // =====================================================
  double _currentTargetLat = 0;
  double _currentTargetLon = 0;

  // =====================================================
  // 🎨 ANIMACIONES Y UI
  // =====================================================
  late AnimationController _arrowPulseController;
  late Animation<double> _arrowPulseAnimation;

  late AnimationController _arrowRotationController;
  late Animation<double> _arrowRotationAnimation;

  bool _isNavigationActive = true;
  bool _hasReachedDestination = false;

  // =====================================================
  // ⚙️ CONFIGURACIÓN
  // =====================================================
  static const double _waypointProximityThreshold = 8.0;
  static const double _destinationThreshold = 5.0;

  // =====================================================
  // 🔥 WAYPOINTS CORREGIDOS
  // =====================================================
  late List<Map<String, dynamic>> _correctedWaypoints;

  @override
  void initState() {
    super.initState();
    _fixWaypointsOrder();
    _initializeComponents();
  }

  // =====================================================
  // 🔥 FIX #1: INVERTIR WAYPOINTS SI VIENEN AL REVÉS
  // =====================================================
  void _fixWaypointsOrder() {
    // Verificar si Mapbox envió waypoints invertidos
    if (widget.routeWaypoints.isEmpty) {
      _correctedWaypoints = [];
      return;
    }

    // Obtener posición inicial aproximada (usaremos last known)
    _correctedWaypoints = List.from(widget.routeWaypoints);

    debugPrint('🗺️ Waypoints recibidos: ${_correctedWaypoints.length}');
    for (int i = 0; i < _correctedWaypoints.length; i++) {
      debugPrint('  WP[$i]: ${_correctedWaypoints[i]}');
    }
  }

  // =====================================================
  // 🚀 INICIALIZACIÓN
  // =====================================================
  Future<void> _initializeComponents() async {
    await _initCamera();
    _initAnimations();
    await _initLocationFirst(); // ✅ Obtener ubicación ANTES de sensores
    _initSensorsFixed(); // ✅ Sensores CORREGIDOS
    _initRouteCalculator();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('❌ Error al inicializar cámara: $e');
    }
  }

  void _initAnimations() {
    _arrowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _arrowPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _arrowPulseController,
      curve: Curves.easeInOut,
    ));

    _arrowRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _arrowRotationAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _arrowRotationController,
      curve: Curves.easeOut,
    ));
  }

  // =====================================================
  // 🔥 FIX #2: OBTENER UBICACIÓN INICIAL
  // =====================================================
  Future<void> _initLocationFirst() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        _currentLat = position.latitude;
        _currentLon = position.longitude;
        _currentAltitude = position.altitude;
      });

      debugPrint('📍 Ubicación inicial: $_currentLat, $_currentLon');

      // ✅ AHORA SÍ: Verificar orden de waypoints
      if (_correctedWaypoints.isNotEmpty) {
        final distToFirst = Geolocator.distanceBetween(
          _currentLat,
          _currentLon,
          _correctedWaypoints.first['lat']!,
          _correctedWaypoints.first['lon']!,
        );

        final distToLast = Geolocator.distanceBetween(
          _currentLat,
          _currentLon,
          _correctedWaypoints.last['lat']!,
          _correctedWaypoints.last['lon']!,
        );

        debugPrint('🔍 Distancia al primer WP: ${distToFirst.toStringAsFixed(1)}m');
        debugPrint('🔍 Distancia al último WP: ${distToLast.toStringAsFixed(1)}m');

        // Si el último está más cerca que el primero, invertir
        if (distToLast < distToFirst) {
          debugPrint('🔄 INVIRTIENDO WAYPOINTS (estaban al revés)');
          _correctedWaypoints = _correctedWaypoints.reversed.toList();
        }
      }

      // Iniciar tracking continuo
      _startLocationTracking();
    } catch (e) {
      debugPrint('❌ Error obteniendo ubicación: $e');
    }
  }

  void _startLocationTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
      if (mounted) {
        setState(() {
          _currentLat = position.latitude;
          _currentLon = position.longitude;
          _currentAltitude = position.altitude;
          _userSpeed = position.speed;
        });
        _updateNavigation();
      }
    });
  }

  // =====================================================
  // 🔥 FIX #3: SENSORES CORREGIDOS
  // =====================================================
  void _initSensorsFixed() {
    // ✅ Variables de smoothing CORRECTAS
    double _filteredHeading = 0;
    bool _headingInitialized = false;
    int _lastUpdateTime = 0;

    // ✅ Parámetros conservadores
    const double alpha = 0.15; // Menos agresivo
    const int minInterval = 50; // 20 FPS max

    _sensorManager.compassStream.listen((rawHeading) {
      if (!mounted || rawHeading == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastUpdateTime < minInterval) return;
      _lastUpdateTime = now;

      // ✅ NORMALIZAR ENTRADA (0-360°)
      double normalizedHeading = rawHeading % 360;
      if (normalizedHeading < 0) normalizedHeading += 360;

      // ✅ Primera lectura
      if (!_headingInitialized) {
        _filteredHeading = normalizedHeading;
        _headingInitialized = true;
        setState(() => _compassHeading = _filteredHeading);
        return;
      }

      // ✅ SMOOTHING CIRCULAR (para 0°/360° transition)
      double diff = normalizedHeading - _filteredHeading;

      // Normalizar diferencia a rango [-180, 180]
      while (diff > 180) diff -= 360;
      while (diff < -180) diff += 360;

      // Aplicar filtro exponencial
      _filteredHeading += alpha * diff;

      // Mantener en rango [0, 360)
      _filteredHeading = _filteredHeading % 360;
      if (_filteredHeading < 0) _filteredHeading += 360;

      setState(() {
        _compassHeading = _filteredHeading;
        _updateArrowRotation();
      });
    });

    // Acelerómetro (pitch/roll)
    _sensorManager.accelerometerStream.listen((event) {
      if (mounted) {
        final pitch = _calculatePitch(event.x, event.y, event.z);
        final roll = _calculateRoll(event.x, event.y, event.z);
        setState(() {
          _pitch = pitch;
          _roll = roll;
        });
      }
    });

    // Accuracy del compass
    FlutterCompass.events?.listen((event) {
      if (event.accuracy != null) {
        setState(() => _compassAccuracy = event.accuracy!.toDouble());
      }
    });
  }

  void _initRouteCalculator() {
    _routeCalculator = ArRouteCalculator(
      waypoints: _correctedWaypoints,
      targetLat: widget.targetLat,
      targetLon: widget.targetLon,
    );

    debugPrint('🧮 Route calculator inicializado con ${_correctedWaypoints.length} waypoints');
  }

  // =====================================================
  // 🧮 CÁLCULOS TRIGONOMÉTRICOS
  // =====================================================
  double _calculatePitch(double x, double y, double z) {
    return math.atan2(y, math.sqrt(x * x + z * z)) * 180 / math.pi;
  }

  double _calculateRoll(double x, double y, double z) {
    return math.atan2(-x, math.sqrt(y * y + z * z)) * 180 / math.pi;
  }

  // =====================================================
  // 🗺️ ACTUALIZACIÓN DE NAVEGACIÓN (CORREGIDA)
  // =====================================================
  void _updateNavigation() {
    if (_currentLat == 0 || _currentLon == 0) return;

    // ✅ Determinar target actual
    if (_currentWaypointIndex < _correctedWaypoints.length) {
      final currentWaypoint = _correctedWaypoints[_currentWaypointIndex];
      _currentTargetLat = currentWaypoint['lat']!;
      _currentTargetLon = currentWaypoint['lon']!;
    } else {
      _currentTargetLat = widget.targetLat;
      _currentTargetLon = widget.targetLon;
    }

    // ✅ Calcular distancia y bearing AL TARGET ACTUAL
    _distanceToNextWaypoint = Geolocator.distanceBetween(
      _currentLat,
      _currentLon,
      _currentTargetLat,
      _currentTargetLon,
    );

    _bearingToWaypoint = _routeCalculator.calculateBearing(
      _currentLat,
      _currentLon,
      _currentTargetLat,
      _currentTargetLon,
    );

    // Distancia total restante
    _totalDistanceRemaining = _routeCalculator.calculateRemainingDistance(
      _currentLat,
      _currentLon,
      _currentWaypointIndex,
    );

    // ✅ Avanzar waypoint si estamos cerca
    if (_currentWaypointIndex < _correctedWaypoints.length &&
        _distanceToNextWaypoint < _waypointProximityThreshold) {
      setState(() => _currentWaypointIndex++);
      _playWaypointSound();
      debugPrint('✅ Waypoint $_currentWaypointIndex alcanzado');
    }

    // ✅ Detectar llegada al destino final
    if (_currentWaypointIndex >= _correctedWaypoints.length) {
      _checkDestinationReached();
    }

    _updateArrowRotation();
  }

  void _checkDestinationReached() {
    final distanceToDestination = Geolocator.distanceBetween(
      _currentLat,
      _currentLon,
      widget.targetLat,
      widget.targetLon,
    );

    debugPrint('🎯 Distancia final: ${distanceToDestination.toStringAsFixed(1)}m');

    if (distanceToDestination < _destinationThreshold &&
        !_hasReachedDestination) {
      setState(() {
        _hasReachedDestination = true;
        _isNavigationActive = false;
      });
      _showDestinationReachedDialog();
      debugPrint('🎉 ¡DESTINO ALCANZADO!');
    }
  }

  // =====================================================
  // 🔥 FIX #4: RELATIVE ANGLE CORRECTO
  // =====================================================
  void _updateArrowRotation() {
    if (_bearingToWaypoint == 0 && _distanceToNextWaypoint == 0) return;

    // ✅ Calcular ángulo relativo CORRECTAMENTE
    double relativeAngle = _bearingToWaypoint - _compassHeading;

    // Normalizar a rango [-180, 180]
    while (relativeAngle > 180) relativeAngle -= 360;
    while (relativeAngle < -180) relativeAngle += 360;

    _arrowRotationAnimation = Tween<double>(
      begin: _arrowRotationAnimation.value,
      end: relativeAngle,
    ).animate(_arrowRotationController);

    _arrowRotationController.forward(from: 0);
  }

  // =====================================================
  // 🎨 UI PRINCIPAL
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraView(),
          if (_isNavigationActive) _buildArrowOverlay(),
          ArHudOverlay(
            distanceToNext: _distanceToNextWaypoint,
            totalDistance: _totalDistanceRemaining,
            currentWaypoint: _currentWaypointIndex + 1,
            totalWaypoints: _correctedWaypoints.length + 1,
            targetName: widget.targetName,
            speed: _userSpeed,
            compassAccuracy: _compassAccuracy,
            isCalibrated: _compassAccuracy < 20,
          ),
          _buildControlButtons(),
          if (_hasReachedDestination) _buildArrivalOverlay(),
          
          // ✅ DEBUG MEJORADO
          Positioned(
            bottom: 100,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black.withOpacity(0.8),
              child: Text(
                '📍 Pos: ${_currentLat.toStringAsFixed(5)}, ${_currentLon.toStringAsFixed(5)}\n'
                '🎯 Target: ${_currentTargetLat.toStringAsFixed(5)}, ${_currentTargetLon.toStringAsFixed(5)}\n'
                '📏 Dist: ${_distanceToNextWaypoint.toStringAsFixed(1)}m\n'
                '🧭 Bear: ${_bearingToWaypoint.toStringAsFixed(1)}°\n'
                '📱 Head: ${_compassHeading.toStringAsFixed(1)}°\n'
                '↗️ Rel: ${_arrowRotationAnimation.value.toStringAsFixed(1)}°\n'
                '📌 WP: $_currentWaypointIndex/${_correctedWaypoints.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildArrowOverlay() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _arrowPulseAnimation,
        _arrowRotationAnimation,
      ]),
      builder: (context, child) {
        return CustomPaint(
          painter: ArArrowPainter(
            compassHeading: _compassHeading,
            pitch: _pitch,
            roll: _roll,
            currentLat: _currentLat,
            currentLon: _currentLon,
            targetLat: _currentTargetLat,
            targetLon: _currentTargetLon,
            distanceToTarget: _distanceToNextWaypoint,
            bearingToTarget: _bearingToWaypoint,
            relativeAngle: _arrowRotationAnimation.value,
            pulseScale: _arrowPulseAnimation.value,
            rotationAngle: _arrowRotationAnimation.value,
            arrowColor: Colors.red,
            isCalibrated: _compassAccuracy < 20,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              mini: true,
              backgroundColor: Colors.black.withOpacity(0.7),
              onPressed: () => _showExitDialog(),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 20),
            Text(
              'Inicializando AR...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalOverlay() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 40, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C).withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🎯 ¡Llegaste a tu destino!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.targetName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: Color(0xFFB71C1C),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir de navegación AR'),
        content: const Text('¿Deseas finalizar la navegación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('SALIR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDestinationReachedDialog() {
    debugPrint('🎯 Destino alcanzado');
  }

  void _playWaypointSound() {
    debugPrint('🎵 Waypoint alcanzado');
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _positionStream?.cancel();
    _sensorManager.dispose();
    _arrowPulseController.dispose();
    _arrowRotationController.dispose();
    super.dispose();
  }
}