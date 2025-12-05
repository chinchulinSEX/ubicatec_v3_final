// =====================================================
// 🎯 AR NAVIGATION 3D - VERSIÓN SIMPLIFICADA + MEJORADA
// =====================================================
// 🔴 Flecha roja precisa (bearing corregido)
// 🟡 Flecha amarilla aparece si:
//    1) Te desvías > 30°
//    2) La brújula NO está calibrada
// 🧭 Calibración visible en HUD y Debug
// 🎉 Mensaje "Llegaste a tu destino"
// 🎯 Sin waypoints, directo al destino
// =====================================================

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../../widgets/ar_arrow_painter.dart';
import '../../widgets/ar_hud_overlay.dart';

class ArNavigation3D extends StatefulWidget {
  final double targetLat;
  final double targetLon;
  final String targetName;
  final List<Map<String, dynamic>>
  
      routeWaypoints; // Ignorado por compatibilidad

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
  // 📷 CÁMARA
  // =====================================================
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // =====================================================
  // 🧭 SENSORES
  // =====================================================
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionStream;

  double _compassHeading = 0;
  double _compassAccuracy = 100;
  bool _isCompassCalibrated = false;

  // =====================================================
  // 📍 UBICACIÓN
  // =====================================================
  double _currentLat = 0;
  double _currentLon = 0;
  double _distanceToDestination = 0;
  double _bearingToDestination = 0;
  double _initialDistance = 0;


  // =====================================================
  // 🎨 ANIMACIONES
  // =====================================================
  late AnimationController _arrowPulseController;
  late Animation<double> _arrowPulseAnimation;

  late AnimationController _arrowRotationController;
  late Animation<double> _arrowRotationAnimation;

  // =====================================================
  // 🎯 ESTADOS
  // =====================================================
  bool _isNavigationActive = true;
  bool _hasReachedDestination = false;
  bool _showCalibrationWarning = false;

  static const double _destinationThreshold = 5.0;

  @override
  void initState() {
    super.initState();
    _initializeComponents();
  }

  Future<void> _initializeComponents() async {
    await _initCamera();
    _initAnimations();
    await _initLocation();
    _initCompass();
  }

  // =====================================================
  // INICIALIZAR CÁMARA
  // =====================================================
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();

      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (_) {}
  }

  // =====================================================
  // ANIMACIONES
  // =====================================================
  void _initAnimations() {
    _arrowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _arrowPulseAnimation =
        Tween<double>(begin: 1.0, end: 1.15).animate(_arrowPulseController);

    _arrowRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _arrowRotationAnimation =
        Tween<double>(begin: 0, end: 0).animate(_arrowRotationController);
  }

  // =====================================================
  // UBICACIÓN
  // =====================================================
  Future<void> _initLocation() async {
  try {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    _currentLat = pos.latitude;
    _currentLon = pos.longitude;

    // ⭐ REGISTRA LA DISTANCIA INICIAL la fakin barra de arriba 
    _initialDistance = Geolocator.distanceBetween(
      _currentLat,
      _currentLon,
      widget.targetLat,
      widget.targetLon,
    );

    _updateNavigation();
    _startLocationTracking();
  } catch (_) {}
}


  void _startLocationTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) {
        if (!mounted) return;

        setState(() {
          _currentLat = p.latitude;
          _currentLon = p.longitude;
        });

        _updateNavigation();
      },
    );
  }

  // =====================================================
  // BRÚJULA
  // =====================================================
  void _initCompass() {
    double filter = 0;
    bool initialized = false;
    int lastUpdate = 0;

    const double alpha = 0.22;
    const int minInterval = 60;

    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (!mounted || event.heading == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastUpdate < minInterval) return;
      lastUpdate = now;

      double raw = event.heading!;
      if (raw < 0) raw += 360;

      if (!initialized) {
        filter = raw;
        initialized = true;
      } else {
        double diff = raw - filter;
        while (diff > 180) diff -= 360;
        while (diff < -180) diff += 360;

        filter += alpha * diff;
        if (filter < 0) filter += 360;
        if (filter >= 360) filter -= 360;
      }

      setState(() {
        _compassHeading = filter;
        _compassAccuracy = event.accuracy?.toDouble() ?? 100;
        _isCompassCalibrated = _compassAccuracy < 20;

        if (!_isCompassCalibrated) _showCalibrationWarning = true;
      });

      _updateArrowRotation();
    });
  }

  // =====================================================
  // NAVEGACIÓN
  // =====================================================
  void _updateNavigation() {
    _distanceToDestination = Geolocator.distanceBetween(
      _currentLat,
      _currentLon,
      widget.targetLat,
      widget.targetLon,
    );

    _bearingToDestination = Geolocator.bearingBetween(
      _currentLat,
      _currentLon,
      widget.targetLat,
      widget.targetLon,
    );

    if (_distanceToDestination < _destinationThreshold &&
        !_hasReachedDestination) {
      setState(() {
        _hasReachedDestination = true;
        _isNavigationActive = false;
      });
    }

    _updateArrowRotation();
  }

  // =====================================================
  // ROTACIÓN SUAVE Y PRECISA
  // =====================================================
  void _updateArrowRotation() {
    double target = _bearingToDestination - _compassHeading;

    while (target > 180) target -= 360;
    while (target < -180) target += 360;

    double current = _arrowRotationAnimation.value;
    double diff = target - current;

    if (diff > 180) target -= 360;
    if (diff < -180) target += 360;

    if (diff.abs() < 1.2) return;

    _arrowRotationAnimation =
        Tween<double>(begin: current, end: target).animate(
      CurvedAnimation(parent: _arrowRotationController, curve: Curves.easeOut),
    );

    _arrowRotationController.forward(from: 0);
  }

  // =====================================================
  // UI / BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return _buildLoading();
    }

    final showYellowArrow =
        (!_isCompassCalibrated || _arrowRotationAnimation.value.abs() > 30);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCamera(),
          if (_isNavigationActive)
            CustomPaint(
              painter: ArArrowPainter(
                compassHeading: _compassHeading,
                pitch: 0,
                roll: 0,
                currentLat: _currentLat,
                currentLon: _currentLon,
                targetLat: widget.targetLat,
                targetLon: widget.targetLon,
                distanceToTarget: _distanceToDestination,
                bearingToTarget: _bearingToDestination,
                relativeAngle: _arrowRotationAnimation.value,
                pulseScale: _arrowPulseAnimation.value,
                rotationAngle: _arrowRotationAnimation.value,
                arrowColor: showYellowArrow ? Colors.amber : Colors.red,
                isCalibrated: _isCompassCalibrated,
              ),
              size: Size.infinite,
            ),
          _buildHUD(),
          if (_hasReachedDestination) _buildArrival(),
          if (_showCalibrationWarning && !_isCompassCalibrated)
            _buildCalibrateMsg(),
          _buildDebug(),
        ],
      ),
    );
  }

  // =====================================================
  // CÁMARA
  // =====================================================
  Widget _buildCamera() {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _cameraController!.value.previewSize!.height,
        height: _cameraController!.value.previewSize!.width,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  // =====================================================
  // HUD
  // =====================================================
  Widget _buildHUD() {
    return ArHudOverlay(
      distanceToNext: _distanceToDestination,
    
      totalDistance: _initialDistance,
      currentWaypoint: 1,
      totalWaypoints: 1,
      targetName: widget.targetName,
      speed: 0,
      compassAccuracy: _compassAccuracy,
      isCalibrated: _isCompassCalibrated,
    );
  }

  // =====================================================
  // MENSAJE DE LLEGADA
  // =====================================================
  Widget _buildArrival() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          "🎯 ¡Llegaste a tu destino!",
          style: TextStyle(color: Colors.greenAccent, fontSize: 22),
        ),
      ),
    );
  }

  // =====================================================
  // AVISO DE CALIBRACIÓN
  // =====================================================
  Widget _buildCalibrateMsg() {
    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          "🧭 Mueve el teléfono en forma de 8\nCalibrando brújula...",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  // =====================================================
  // DEBUG
  // =====================================================
  Widget _buildDebug() {
    return Positioned(
      bottom: 80,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.black54,
        child: Text(
          "📍 Pos: ${_currentLat.toStringAsFixed(6)}, ${_currentLon.toStringAsFixed(6)}\n"
          "🎯 Destino: ${widget.targetLat.toStringAsFixed(6)}, ${widget.targetLon.toStringAsFixed(6)}\n"
          "📏 Distancia: ${_distanceToDestination.toStringAsFixed(1)} m\n"
          "🧭 Bearing: ${_bearingToDestination.toStringAsFixed(1)}°\n"
          "📱 Heading: ${_compassHeading.toStringAsFixed(1)}°\n"
          "↗️ RelAngle: ${_arrowRotationAnimation.value.toStringAsFixed(1)}°\n"
          "📌 Estado: ${_isCompassCalibrated ? "Calibrado" : "⚠️ Calibrar brújula"}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: "monospace",
          ),
        ),
      ),
    );
  }

  // =====================================================
  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.red),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _compassSubscription?.cancel();
    _positionStream?.cancel();
    _arrowPulseController.dispose();
    _arrowRotationController.dispose();
    super.dispose();
  }
}
