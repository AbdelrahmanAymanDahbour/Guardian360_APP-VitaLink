class SensorFrame {
  final double gForce;
  final double rotation;
  final DateTime timestamp;

  SensorFrame({
    required this.gForce,
    required this.rotation,
    required this.timestamp,
  });
}
