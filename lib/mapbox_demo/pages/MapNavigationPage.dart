import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

// IMPORTANTE: necesitas este import para abrir el AR
import 'ar_navigation_3d.dart'; // <-- AJUSTA la ruta si tu carpeta AR está en otro lado

/// 🚗 Navegación estilo Google Maps / Yango Pro
class MapNavigationPage extends StatefulWidget {
  final double destLat;
  final double destLon;
  final String destName;

  const MapNavigationPage({
    super.key,
    required this.destLat,
    required this.destLon,
    required this.destName,
  });

  @override
  State<MapNavigationPage> createState() => _MapNavigationPageState();
}

class _MapNavigationPageState extends State<MapNavigationPage> {
  // ============================
  // 🔧 MANEJO DE MAPBOX + RUTAS
  // ============================
  mp.MapboxMap? map;
  mp.PolylineAnnotationManager? _routeManager;
  mp.PolylineAnnotation? _route; // <- aquí se guarda la ruta completa

  // ============================
  // 📍 UBICACIÓN ACTUAL
  // ============================
  gl.Position? _currentPos;
  StreamSubscription<gl.Position>? _posStream;

  // ============================
  // UI + ESTADOS
  // ============================
  bool _loading = true;
  bool _recalculando = false;
  bool _isDriving = false; // 🚘 Auto por defecto
  bool _darkMode = true; // 🌙 Modo oscuro del mapa

  String _tiempoEstimado = "";
  String _distancia = "";
  List<String> _instrucciones = [];
  int _paso = 0;

  @override
  void initState() {
    super.initState();
    _initLocation(); // Inicia GPS + seguimiento
  }

  @override
  void dispose() {
    _posStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ==================================================
          // 🗺️ MAPA PRINCIPAL DE MAPBOX
          // ==================================================
          mp.MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: _darkMode
                ? mp.MapboxStyles.DARK
                : mp.MapboxStyles.MAPBOX_STREETS,
          ),

          // ==================================================
          // 🧭 PANEL DE NAVEGACIÓN PARA GIROS
          // ==================================================
          if (_instrucciones.isNotEmpty)
            Positioned(
              top: 40,
              left: 15,
              right: 15,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 🚗 / 🚶 ICONO DE MODO
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _isDriving
                            ? Icons.directions_car
                            : Icons.directions_walk,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 📜 INSTRUCCIONES + DISTANCIA + TIEMPO
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _instrucciones[_paso],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.timer,
                                  size: 16, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(_tiempoEstimado,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(width: 12),
                              const Icon(Icons.place,
                                  size: 16, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(_distancia,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 🎛 BOTONES DEL PANEL (Cerrar / Cambiar modo)
                    Column(
                      children: [
                        IconButton(
                          tooltip: "Cerrar navegación",
                          onPressed: () {
                            _posStream?.cancel();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 22),
                        ),
                        IconButton(
                          tooltip: "Cambiar modo Auto/Caminando",
                          onPressed: () async {
                            setState(() {
                              _isDriving = !_isDriving;
                              _loading = true;
                            });
                            if (_currentPos != null) {
                              await _dibujarRuta(
                                  widget.destLat, widget.destLon);
                            }
                            setState(() => _loading = false);
                          },
                          icon: Icon(
                            _isDriving
                                ? Icons.directions_car
                                : Icons.directions_walk,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ==================================================
          // 🔴 BOTÓN PARA ABRIR EL MODO AR 3D
          // ==================================================
          if (_route != null) // Solo se muestra cuando ya existe la ruta
            Positioned(
              bottom: 40,
              right: 20,
              child: FloatingActionButton(
                heroTag: "ar_button",
                backgroundColor: Colors.redAccent,
                onPressed: _abrirModoAr,
                child:
                    const Icon(Icons.view_in_ar, color: Colors.white, size: 28),
              ),
            ),

          // ==================================================
          // ⏳ LOADING MIENTRAS CALCULA RUTA
          // ==================================================
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // 📍 Inicializa ubicación + seguimiento del usuario
  // ============================================================
  Future<void> _initLocation() async {
    await _checkPermisos();

    const settings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.best,
      distanceFilter: 2,
    );

    _posStream?.cancel();
    _posStream = gl.Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) async {
      _currentPos = pos;

      // mueve cámara
      if (map != null) {
        _centrarCamara(pos.latitude, pos.longitude, heading: pos.heading);
      }

      // si ya hay ruta, actualiza progreso
      if (_route != null) {
        await _actualizarProgreso(widget.destLat, widget.destLon);
      }
    });
  }

  // ============================================================
  // 🗺️ Cuando el mapa está listo
  // ============================================================
  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    map = controller;

    // Activa ubicación pulsante
    await map!.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        showAccuracyRing: false,
      ),
    );

    _routeManager = await map!.annotations.createPolylineAnnotationManager();

    _currentPos = await gl.Geolocator.getCurrentPosition(
      desiredAccuracy: gl.LocationAccuracy.best,
    );

    if (_currentPos != null) {
      await _dibujarRuta(widget.destLat, widget.destLon);
      await _centrarCamara(_currentPos!.latitude, _currentPos!.longitude);
    }

    setState(() => _loading = false);
  }

  // ============================================================
  // 🎯 GENERA LA RUTA usando Mapbox Directions
  // ============================================================
  Future<void> _dibujarRuta(double destLat, double destLon) async {
    final start = "${_currentPos!.longitude},${_currentPos!.latitude}";
    final end = "$destLon,$destLat";
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    final profile = _isDriving ? "driving" : "walking";

    final url = Uri.parse(
      "https://api.mapbox.com/directions/v5/mapbox/$profile/$start;$end"
      "?geometries=geojson&overview=full&steps=true"
      "&annotations=maxspeed,congestion,distance"
      "&access_token=$token",
    );

    try {
      final res = await http.get(url);
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final route = data['routes'][0];
      final coords = route['geometry']['coordinates'] as List;

      final puntos = coords
          .map((c) => mp.Position(c[0].toDouble(), c[1].toDouble()))
          .toList();

      // limpia y dibuja ruta
      await _routeManager?.deleteAll();
      _route = await _routeManager!.create(
        mp.PolylineAnnotationOptions(
          geometry: mp.LineString(coordinates: puntos),
          lineColor: _isDriving ? 0xFF00B0FF : 0xFF43A047,
          lineWidth: 7.5,
        ),
      );

      // calcula tiempo/distancia
      final distanciaMetros = route['distance'] ?? 0;
      final duracionSeg = route['duration'] ?? 0;

      _distancia = "${(distanciaMetros / 1000).toStringAsFixed(1)} km";
      _tiempoEstimado = "${(duracionSeg / 60).toStringAsFixed(0)} min";

      // instrucciones paso a paso
      final pasos = route['legs'][0]['steps'] as List;
      setState(() {
        _instrucciones = pasos.map<String>((s) {
          final maniobra = s['maneuver']['modifier'] ?? 'seguir';
          final nombre = s['name'] ?? 'camino';
          switch (maniobra) {
            case 'left':
              return "⬅️ Girar a la izquierda por $nombre";
            case 'right':
              return "➡️ Girar a la derecha por $nombre";
            default:
              return "⬆️ Seguir por $nombre";
          }
        }).toList();
        _paso = 0;
        _darkMode = true;
      });
    } catch (e) {
      debugPrint("❌ Error al generar ruta: $e");
    }
  }

  // ============================================================
  // 📡 Mueve la cámara estilo Yango
  // ============================================================
  Future<void> _centrarCamara(double lat, double lon, {double? heading}) async {
    await map?.setCamera(
      mp.CameraOptions(
        center: mp.Point(coordinates: mp.Position(lon, lat)),
        zoom: _isDriving ? 17.5 : 16.5,
        pitch: 60,
        bearing: heading ?? 0,
      ),
    );
  }

  // ============================================================
  // 🚶 Actualiza progreso y detecta llegada
  // ============================================================
  Future<void> _actualizarProgreso(double destLat, double destLon) async {
    if (_currentPos == null || _route == null || _recalculando) return;

    final distancia = gl.Geolocator.distanceBetween(
      _currentPos!.latitude,
      _currentPos!.longitude,
      destLat,
      destLon,
    );

    if (distancia < 5) {
      _posStream?.cancel();
      await _routeManager?.deleteAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎯 Has llegado al destino"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    // si saliste de la ruta → recalcula
    if (!_estasEnRuta()) {
      _recalculando = true;
      await _dibujarRuta(destLat, destLon);
      _recalculando = false;
    }
  }

  bool _estasEnRuta() {
    if (_route == null || _currentPos == null) return true;

    const tolerancia = 15.0;
    for (final p in _route!.geometry.coordinates) {
      final dist = gl.Geolocator.distanceBetween(
        _currentPos!.latitude,
        _currentPos!.longitude,
        p.lat.toDouble(),
        p.lng.toDouble(),
      );
      if (dist < tolerancia) return true;
    }
    return false;
  }

  // ============================================================
  // ✔️ Verifica permisos de ubicación
  // ============================================================
  Future<void> _checkPermisos() async {
    bool activo = await gl.Geolocator.isLocationServiceEnabled();
    if (!activo) return Future.error('⚠️ GPS apagado');

    gl.LocationPermission permiso = await gl.Geolocator.checkPermission();
    if (permiso == gl.LocationPermission.denied) {
      permiso = await gl.Geolocator.requestPermission();
      if (permiso == gl.LocationPermission.denied) {
        return Future.error('❌ Permiso denegado');
      }
    }
    if (permiso == gl.LocationPermission.deniedForever) {
      return Future.error('🚫 Permiso denegado permanentemente');
    }
  }

  // ============================================================
  // ⭐⭐⭐ AQUI ESTÁ EL MOTOR: ABRIR EL AR DESDE AQUI LLAMAMOS AL AR ⭐⭐⭐
  // ============================================================
  void _abrirModoAr() {
    if (_route == null) return;
    print(widget.destLat + widget.destLon);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArNavigation3D(
          targetLat: widget.destLat,
          targetLon: widget.destLon,
          targetName: widget.destName,

          // WAYPOINTS desde Mapbox → AR
          routeWaypoints: _route!.geometry.coordinates
              .map((p) => {
                    'lat': p.lat.toDouble(), // latitude real
                    'lon': p.lng.toDouble(), // longitude real
                  })
              .toList(),
        ),
      ),
    );
  }
}
