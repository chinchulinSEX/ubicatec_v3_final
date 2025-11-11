// =====================================================
// 📊 AR HUD OVERLAY (compacto) — FIX baseline
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
    const double hMargin = 12;
    const double pad = 10;
    const double radius = 12;
    const double titleSize = 14;
    const double numberSize = 28;
    const double unitSize = 14;
    const double waypointSize = 12;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: hMargin),
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.80),
            Colors.black.withOpacity(0.60),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
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
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // ✅ FIX: baseline correcto
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
                  fontSize: numberSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                distanceToNext < 1000 ? 'm' : 'km',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: unitSize,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            'Punto $currentWaypoint de $totalWaypoints',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: waypointSize,
            ),
          ),
          const SizedBox(height: 6),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (totalWaypoints == 0)
        ? 0.0
        : (currentWaypoint / totalWaypoints).clamp(0.0, 1.0);

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
          '${(progress * 100).toStringAsFixed(0)}% completado',
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
            label: isCalibrated ? 'OK' : 'Calibrar',
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

