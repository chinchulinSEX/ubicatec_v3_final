// ✅ NUEVA PANTALLA AR COMPLETA CON AR FLUTTER PLUGIN (CORREGIDO)
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:vector_math/vector_math_64.dart' as vector;

// ✅ AR IMPORTS (4 MANAGERS - RECIBIMOS TODOS PERO SOLO USAMOS 3)
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart'; // ✅ SÍ lo importamos
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter_compass/flutter_compass.dart';

class ARNavigationScreen extends StatefulWidget {
  final double destLat;
  final double destLon;
  final String destName;

  const ARNavigationScreen({
    super.key,
    required this.destLat,
    required this.destLon,
    required this.destName,
  });

  @override
  State<ARNavigationScreen> createState() => _ARNavigationScreenState();
}

class _ARNavigationScreenState extends State<ARNavigationScreen> {
  // ✅ MANAGERS DE AR
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;
  // No declaramos _arLocationManager porque no lo usamos

  // 📍 Ubicación y sensores
  gl.Position? _currentPos;
  StreamSubscription<gl.Position>? _posStream;
  StreamSubscription<CompassEvent>? _compassStream;
  double _heading = 0;

  // 🎯 Estado de navegación
  String _distanceText = "Calculando...";
  String _directionText = "Apunta la cámara";
  bool _arReady = false;
  bool _destinationReached = false;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _startCompassTracking();
  }

  @override
  void dispose() {
    _posStream?.cancel();
    _compassStream?.cancel();
    _arSessionManager?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🧭 TRACKING DE UBICACIÓN Y BRÚJULA
  // ═══════════════════════════════════════════════════════════
  
  Future<void> _startLocationTracking() async {
    const settings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.best,
      distanceFilter: 2,
    );

    _posStream = gl.Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
      setState(() {
        _currentPos = pos;
        _updateNavigationInfo();
      });
    });
  }

  void _startCompassTracking() {
    _compassStream = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        setState(() => _heading = event.heading!);
      }
    });
  }

  void _updateNavigationInfo() {
    if (_currentPos == null) return;

    final distance = gl.Geolocator.distanceBetween(
      _currentPos!.latitude,
      _currentPos!.longitude,
      widget.destLat,
      widget.destLon,
    );

    setState(() {
      _distanceText = distance < 1000
          ? "${distance.toStringAsFixed(0)} m"
          : "${(distance / 1000).toStringAsFixed(1)} km";

      if (distance < 5) {
        _destinationReached = true;
        _directionText = "🎯 ¡Has llegado!";
      } else {
        final bearing = gl.Geolocator.bearingBetween(
          _currentPos!.latitude,
          _currentPos!.longitude,
          widget.destLat,
          widget.destLon,
        );
        final relativeBearing = (bearing - _heading + 360) % 360;

        if (relativeBearing < 30 || relativeBearing > 330) {
          _directionText = "⬆️ Sigue recto";
        } else if (relativeBearing >= 30 && relativeBearing < 150) {
          _directionText = "➡️ Gira a la derecha";
        } else if (relativeBearing >= 150 && relativeBearing < 210) {
          _directionText = "↩️ Da la vuelta";
        } else {
          _directionText = "⬅️ Gira a la izquierda";
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 INICIALIZACIÓN DE AR
  // ═══════════════════════════════════════════════════════════
  
  Future<void> _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager, // ✅ Lo recibimos pero no lo usamos
  ) async {
    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;
    _arAnchorManager = arAnchorManager;
    // No guardamos arLocationManager porque no lo necesitamos

    await _arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handlePans: false,
      handleRotation: false,
    );

    await _arObjectManager!.onInitialize();

    setState(() => _arReady = true);

    // 🎯 Colocar flecha 3D
    await _placeARArrow();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 COLOCAR FLECHA 3D EN AR
  // ═══════════════════════════════════════════════════════════
  
  Future<void> _placeARArrow() async {
    if (_arObjectManager == null || _currentPos == null) return;

    final distance = gl.Geolocator.distanceBetween(
      _currentPos!.latitude,
      _currentPos!.longitude,
      widget.destLat,
      widget.destLon,
    );

    final bearing = gl.Geolocator.bearingBetween(
      _currentPos!.latitude,
      _currentPos!.longitude,
      widget.destLat,
      widget.destLon,
    );

    // 🧭 Convertir bearing a coordenadas 3D
    final radians = bearing * (math.pi / 180);
    final x = distance * math.sin(radians);
    final z = -distance * math.cos(radians);

    try {
      // 🔴 FLECHA 3D (modelo GLB online)
      final arrowNode = ARNode(
        type: NodeType.webGLB,
        uri: 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Arrow/glTF-Binary/Arrow.glb',
        scale: vector.Vector3(2.0, 2.0, 2.0),
        position: vector.Vector3(x.clamp(-10, 10), 0, z.clamp(-10, 10)),
        rotation: vector.Vector4(0, 1, 0, 0),
      );

      await _arObjectManager!.addNode(arrowNode);
      debugPrint('✅ Flecha AR colocada en ($x, 0, $z)');
    } catch (e) {
      debugPrint('❌ Error colocando flecha: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 UI
  // ═══════════════════════════════════════════════════════════
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🎥 VISTA AR (onARViewCreated recibe 4 parámetros)
          ARView(
            onARViewCreated: _onARViewCreated, // ✅ Acepta 4 parámetros
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
          ),

          // 📊 HUD SUPERIOR
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.destName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _distanceText,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _directionText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ⚠️ MENSAJE DE ESTADO
          if (!_arReady)
            const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),

          // 🎯 DESTINO ALCANZADO
          if (_destinationReached)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '🎉 ¡Llegaste al destino!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 🔙 BOTÓN CERRAR
          Positioned(
            top: 50,
            left: 16,
            child: FloatingActionButton(
              heroTag: 'close_ar',
              backgroundColor: Colors.redAccent,
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}