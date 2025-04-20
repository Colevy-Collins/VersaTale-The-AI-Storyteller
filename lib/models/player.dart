// lib/models/player.dart

/// Strongly‑typed representation of a lobby player slot.
class Player {
  final int slot;
  final String userId;
  String displayName;

  Player({
    required this.slot,
    required this.userId,
    required this.displayName,
  });

  factory Player.fromJson(int slot, Map<String, dynamic> json) => Player(
    slot: slot,
    userId: json['userId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'Anonymous',
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
  };
}
