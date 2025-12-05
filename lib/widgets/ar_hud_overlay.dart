// =====================================================
// 📊 AR HUD OVERLAY - MEJORADO Y CORREGIDO
// =====================================================
// ✅ Porcentaje dinámico real basado en distancia
// ✅ No muestra 100% hasta llegar
// ✅ Muestra mensaje "Llegaste" cuando estás cerca
// ✅ Incluye aviso de calibración si es necesario
// =====================================================

import 'package:flutter/material.dart';

class ArHudOverlay extends StatelessWidget {
  final double distanceToNext;
  final double totalDistance;
  final int currentWaypoint;
  final int totalWaypoints;
  final String targetName;
  final double speed;
  final double compassAccuracy;
  final bool isCalibrated;
  final double progressPercentage;
  final bool hasArrived;

  const ArHudOverlay({
    super.key,
    required this.distanceToNext,
    required this.totalDistance,
    required this.currentWaypoint,
    required this.totalWaypoints,
    required this.targetName,
    required this.speed,
    required this.compassAccuracy,
    required this.isCalibrated,
    this.progressPercentage = 0,
    this.hasArrived = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 60),
          _buildMainInfoPanel(context),
          const Spacer(),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildMainInfoPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.80),
            Colors.black.withOpacity(0.60),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            targetName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                distanceToNext < 1000
                    ? distanceToNext.toStringAsFixed(0)
                    : (distanceToNext / 1000).toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                distanceToNext < 1000 ? 'm' : 'km',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Punto $currentWaypoint de $totalWaypoints',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          _buildProgressBar(),
          if (hasArrived) ...[
            const SizedBox(height: 4),
            const Text(
              '✅ Llegaste a tu destino',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (progressPercentage / 100).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${progressPercentage.toStringAsFixed(0)}% completado',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.70),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoChip(
            icon: Icons.speed,
            label: '${(speed * 3.6).toStringAsFixed(1)} km/h',
            color: Colors.blue,
          ),
          const SizedBox(width: 10),
          _buildInfoChip(
            icon: Icons.route,
            label: totalDistance < 1000
                ? '${totalDistance.toStringAsFixed(0)} m'
                : '${(totalDistance / 1000).toStringAsFixed(1)} km',
            color: Colors.orange,
          ),
          const SizedBox(width: 10),
          _buildInfoChip(
            icon: isCalibrated ? Icons.check_circle : Icons.warning_amber,
            label: isCalibrated ? 'OK' : '📱 Mueve en 8',
            color: isCalibrated ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

//HOLAAAAAAA CLAUDE
