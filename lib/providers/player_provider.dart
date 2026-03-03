import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../services/storage_service.dart';

const _uuid = Uuid();
const _remoteCsvUrl =
    'https://raw.githubusercontent.com/GuySchnidrig/ManaCore/main/data/processed/players.csv';

/// Parses a CSV body and returns the player names found in column 1.
/// Skips the header row, empty names, and "Missing Player" entries.
List<String> parseCsvToNames(String csvBody) {
  final names = <String>[];
  for (final line in csvBody.split('\n').skip(1)) {
    final cols = line.split(',');
    if (cols.length < 2) continue;
    final name = cols[1].trim();
    if (name.isEmpty || name == 'Missing Player') continue;
    names.add(name);
  }
  return names;
}

class PlayerProvider extends ChangeNotifier {
  List<Player> _players = [];

  List<Player> get players => List.unmodifiable(_players);

  List<Player> get sortedPlayers {
    final sorted = List<Player>.from(_players);
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  Future<void> init() async {
    _players = StorageService.loadPlayers();
    notifyListeners();
    await _syncRemote();
  }

  Future<void> _syncRemote() async {
    try {
      final res = await http.get(Uri.parse(_remoteCsvUrl));
      if (res.statusCode != 200) return;
      final names = parseCsvToNames(res.body);
      bool changed = false;
      for (final name in names) {
        final exists = _players.any(
          (p) => p.name.toLowerCase() == name.toLowerCase(),
        );
        if (!exists) {
          _players.add(Player(id: _uuid.v4(), name: name));
          changed = true;
        }
      }
      if (changed) {
        await StorageService.savePlayers(_players);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> addPlayer(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _players.add(Player(id: _uuid.v4(), name: trimmed));
    await StorageService.savePlayers(_players);
    notifyListeners();
  }

  Future<void> editPlayer(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final idx = _players.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _players[idx] = _players[idx].copyWith(name: trimmed);
    await StorageService.savePlayers(_players);
    notifyListeners();
  }

  Future<void> deletePlayer(String id) async {
    _players.removeWhere((p) => p.id == id);
    await StorageService.savePlayers(_players);
    notifyListeners();
  }

  Player? getById(String id) {
    try {
      return _players.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String nameOf(String id) => getById(id)?.name ?? id;
}
