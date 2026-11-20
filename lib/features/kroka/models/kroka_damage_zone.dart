class KrokaDamageZone {
  const KrokaDamageZone({
    required this.id,
    required this.side,
    required this.labelKey,
  });

  final String id;

  /// Backward-compatible general side:
  /// front / back / left / right.
  final String side;

  /// Localization key used by UI and saved reports.
  final String labelKey;

  static const String sideFront = 'front';
  static const String sideBack = 'back';
  static const String sideLeft = 'left';
  static const String sideRight = 'right';

  static const Set<String> validSides = {
    sideFront,
    sideBack,
    sideLeft,
    sideRight,
  };

  static const KrokaDamageZone front = KrokaDamageZone(
    id: 'front',
    side: sideFront,
    labelKey: 'kroka.damage.front',
  );

  static const KrokaDamageZone frontLeft = KrokaDamageZone(
    id: 'front_left',
    side: sideFront,
    labelKey: 'kroka.damage.front_left',
  );

  static const KrokaDamageZone frontRight = KrokaDamageZone(
    id: 'front_right',
    side: sideFront,
    labelKey: 'kroka.damage.front_right',
  );

  static const KrokaDamageZone leftFrontDoor = KrokaDamageZone(
    id: 'left_front_door',
    side: sideLeft,
    labelKey: 'kroka.damage.left_front_door',
  );

  static const KrokaDamageZone leftRearDoor = KrokaDamageZone(
    id: 'left_rear_door',
    side: sideLeft,
    labelKey: 'kroka.damage.left_rear_door',
  );

  static const KrokaDamageZone rightFrontDoor = KrokaDamageZone(
    id: 'right_front_door',
    side: sideRight,
    labelKey: 'kroka.damage.right_front_door',
  );

  static const KrokaDamageZone rightRearDoor = KrokaDamageZone(
    id: 'right_rear_door',
    side: sideRight,
    labelKey: 'kroka.damage.right_rear_door',
  );

  static const KrokaDamageZone rearLeft = KrokaDamageZone(
    id: 'rear_left',
    side: sideBack,
    labelKey: 'kroka.damage.rear_left',
  );

  static const KrokaDamageZone rearRight = KrokaDamageZone(
    id: 'rear_right',
    side: sideBack,
    labelKey: 'kroka.damage.rear_right',
  );

  static const KrokaDamageZone back = KrokaDamageZone(
    id: 'back',
    side: sideBack,
    labelKey: 'kroka.damage.back',
  );

  static const List<KrokaDamageZone> values = [
    front,
    frontLeft,
    frontRight,
    leftFrontDoor,
    leftRearDoor,
    rightFrontDoor,
    rightRearDoor,
    rearLeft,
    rearRight,
    back,
  ];

  static KrokaDamageZone? maybeFromId(String id) {
    final safeId = id.trim();

    if (safeId.isEmpty) return null;

    for (final zone in values) {
      if (zone.id == safeId) return zone;
    }

    return null;
  }

  static bool isValidId(String id) {
    return maybeFromId(id) != null;
  }

  static bool isValidSide(String side) {
    return validSides.contains(side.trim());
  }

  static List<KrokaDamageZone> zonesFromSide(String side) {
    final safeSide = side.trim();

    if (!isValidSide(safeSide)) return const [];

    return values.where((zone) => zone.side == safeSide).toList();
  }

  /// Compatibility helper.
  ///
  /// A side may contain multiple precise zones, so this returns the first
  /// matching zone only. Prefer [zonesFromSide] when all zones are needed.
  static KrokaDamageZone? maybeFromSide(String side) {
    final zones = zonesFromSide(side);

    if (zones.isEmpty) return null;

    return zones.first;
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'side': side, 'labelKey': labelKey};
  }
}
