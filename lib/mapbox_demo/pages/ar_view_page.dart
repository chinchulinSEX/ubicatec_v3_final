// file: lib/mapbox_demo/pages/ar_view_page.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class ARViewPage extends StatefulWidget {
  final CameraDescription camera;
  final String imagePath;
  final String titulo;

  const ARViewPage({
    super.key,
    required this.camera,
    required this.imagePath,
    required this.titulo,
  });

  @override
  State<ARViewPage> createState() => _ARViewPageState();
}

class _ARViewPageState extends State<ARViewPage> {
  CameraController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _controller = CameraController(widget.camera, ResolutionPreset.high);
      await _controller!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      debugPrint("Error al inicializar cámara: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🎥 Cámara activa
          CameraPreview(_controller!),

          // 🔴 Imagen SIEMPRE visible (sin GPS ni distancia)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: MediaQuery.of(context).size.width * 0.3,
            child: Column(
              children: [
                Image.asset(
                  widget.imagePath,
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // 🔙 Botón volver
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
