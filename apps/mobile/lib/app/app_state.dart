import 'package:flutter/foundation.dart';

import '../infra/backend_api.dart';

class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.online,
    this.seatCount = 12,
  });

  final String id;
  final String name;
  final String ownerName;
  final int online;
  final int seatCount;
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.name,
    required this.preview,
    this.unread = 0,
  });

  final String id;
  final String name;
  final String preview;
  final int unread;
}

class AppState extends ChangeNotifier {
  AppState();

  final BackendApi backend = const BackendApi();

  String userId = '91000001';
  String displayName = 'DarkVibeX User';
  String? sessionToken;
  bool backendConnected = false;
  int coins = 2500000;
  int diamonds = 120;
  int vipLevel = 1;

  final List<RoomSummary> rooms = <RoomSummary>[
    const RoomSummary(id: '100001', name: 'Dark Lounge', ownerName: 'Alex', online: 18, seatCount: 12),
    const RoomSummary(id: '100002', name: 'Music Night', ownerName: 'Mika', online: 9, seatCount: 10),
    const RoomSummary(id: '100003', name: 'Chill Zone', ownerName: 'Sara', online: 24, seatCount: 15),
  ];

  final List<DirectMessage> messages = <DirectMessage>[
    const DirectMessage(id: '90001', name: 'Mika', preview: 'See you in the room 👋', unread: 2),
    const DirectMessage(id: '90002', name: 'Sara', preview: 'Gift received, thanks!'),
  ];

  Future<void> initialize() async {
    if (!backend.configured) return;
    try {
      final session = await backend.startGuestSession(
        userId: userId,
        displayName: displayName,
      );
      final token = session?['token']?.toString();
      final user = session?['user'];
      if (token != null && token.isNotEmpty) {
        sessionToken = token;
        backendConnected = true;
      }
      if (user is Map) {
        userId = user['id']?.toString() ?? userId;
        displayName = user['display_name']?.toString() ?? displayName;
        coins = int.tryParse(user['coins']?.toString() ?? '') ?? coins;
        diamonds = int.tryParse(user['diamonds']?.toString() ?? '') ?? diamonds;
        vipLevel = int.tryParse(user['vip_level']?.toString() ?? '') ?? vipLevel;
      }

      final remoteRooms = await backend.listRooms();
      if (remoteRooms.isNotEmpty) {
        rooms
          ..clear()
          ..addAll(remoteRooms.map((row) => RoomSummary(
                id: row['id']?.toString() ?? '',
                name: row['name']?.toString() ?? 'Room',
                ownerName: row['owner_name']?.toString() ?? '',
                online: int.tryParse(row['online']?.toString() ?? '') ?? 0,
                seatCount: int.tryParse(row['seat_count']?.toString() ?? '') ?? 12,
              )));
      }
    } catch (_) {
      backendConnected = false;
      sessionToken = null;
    }
    notifyListeners();
  }

  RoomSummary createRoom(String name, {int seatCount = 12}) {
    final room = RoomSummary(
      id: (100000 + rooms.length + 1).toString(),
      name: name.trim().isEmpty ? 'New Room' : name.trim(),
      ownerName: displayName,
      online: 1,
      seatCount: seatCount,
    );
    rooms.insert(0, room);
    notifyListeners();
    return room;
  }

  bool spendCoins(int amount) {
    if (amount <= 0 || amount > coins) return false;
    coins -= amount;
    notifyListeners();
    return true;
  }

  void addCoins(int amount) {
    if (amount <= 0) return;
    coins += amount;
    notifyListeners();
  }

  void addDiamonds(int amount) {
    if (amount <= 0) return;
    diamonds += amount;
    notifyListeners();
  }
}
