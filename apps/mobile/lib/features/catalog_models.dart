class CatalogItem {
  const CatalogItem({
    required this.kind,
    required this.id,
    required this.name,
    required this.priceCoins,
    required this.data,
    this.category = '',
    this.emoji = '✨',
    this.effect = 'compact',
  });

  final String kind;
  final String id;
  final String name;
  final int priceCoins;
  final Map<String, dynamic> data;
  final String category;
  final String emoji;
  final String effect;

  factory CatalogItem.fromMap(Map<String, dynamic> map) {
    final rawData = map['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    return CatalogItem(
      kind: map['kind']?.toString() ?? '',
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Item',
      priceCoins: int.tryParse(map['price_coins']?.toString() ?? '') ?? 0,
      data: data,
      category: data['category']?.toString() ?? '',
      emoji: data['emoji']?.toString() ?? '✨',
      effect: data['effect']?.toString() ?? 'compact',
    );
  }
}

class RoomMember {
  const RoomMember({
    required this.userId,
    required this.displayName,
    required this.seatIndex,
    required this.micMuted,
    required this.vipLevel,
  });

  final String userId;
  final String displayName;
  final int? seatIndex;
  final bool micMuted;
  final int vipLevel;

  factory RoomMember.fromMap(Map<String, dynamic> map) => RoomMember(
        userId: map['user_id']?.toString() ?? '',
        displayName: map['display_name']?.toString() ?? 'User',
        seatIndex: map['seat_index'] == null
            ? null
            : int.tryParse(map['seat_index'].toString()),
        micMuted: (int.tryParse(map['mic_muted']?.toString() ?? '') ?? 1) != 0,
        vipLevel: int.tryParse(map['vip_level']?.toString() ?? '') ?? 0,
      );
}

class RelationshipProgress {
  const RelationshipProgress({
    required this.kind,
    required this.progress,
    required this.level,
    required this.previousThreshold,
    required this.nextThreshold,
  });

  final String kind;
  final int progress;
  final int level;
  final int previousThreshold;
  final int? nextThreshold;

  factory RelationshipProgress.fromMap(Map<String, dynamic> map) =>
      RelationshipProgress(
        kind: map['kind']?.toString() ?? '',
        progress: int.tryParse(map['progress']?.toString() ?? '') ?? 0,
        level: int.tryParse(map['level']?.toString() ?? '') ?? 1,
        previousThreshold:
            int.tryParse(map['previous_threshold']?.toString() ?? '') ?? 0,
        nextThreshold: map['next_threshold'] == null
            ? null
            : int.tryParse(map['next_threshold'].toString()),
      );

  double get fraction {
    final next = nextThreshold;
    if (next == null || next <= previousThreshold) return 1;
    return ((progress - previousThreshold) / (next - previousThreshold))
        .clamp(0, 1)
        .toDouble();
  }
}
