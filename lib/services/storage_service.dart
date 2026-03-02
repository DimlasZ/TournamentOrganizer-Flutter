import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/player.dart';
import '../models/tournament.dart';

class StorageService {
  static const _playersKey = 'players';
  static const _activeTournamentKey = 'activeTournament';
  static const _pastTournamentsKey = 'pastTournaments';
  static const _ghTokenKey = 'gh_pat';

  static late Box _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('tournament_organizer');
  }

  // --- Players ---
  static List<Player> loadPlayers() {
    final raw = _box.get(_playersKey);
    if (raw == null) return [];
    final list = jsonDecode(raw as String) as List;
    return list.map((e) => Player.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static Future<void> savePlayers(List<Player> players) async {
    await _box.put(_playersKey, jsonEncode(players.map((p) => p.toJson()).toList()));
  }

  // --- Active Tournament ---
  static Tournament? loadActiveTournament() {
    final raw = _box.get(_activeTournamentKey);
    if (raw == null) return null;
    return Tournament.fromJson(Map<String, dynamic>.from(jsonDecode(raw as String) as Map));
  }

  static Future<void> saveActiveTournament(Tournament? tournament) async {
    if (tournament == null) {
      await _box.delete(_activeTournamentKey);
    } else {
      await _box.put(_activeTournamentKey, jsonEncode(tournament.toJson()));
    }
  }

  // --- Past Tournaments ---
  static List<Tournament> loadPastTournaments() {
    final raw = _box.get(_pastTournamentsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw as String) as List;
    return list
        .map((e) => Tournament.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> savePastTournaments(List<Tournament> tournaments) async {
    await _box.put(
      _pastTournamentsKey,
      jsonEncode(tournaments.map((t) => t.toJson()).toList()),
    );
  }

  // --- GitHub Token ---
  static String? loadGhToken() => _box.get(_ghTokenKey) as String?;

  static Future<void> saveGhToken(String token) async {
    await _box.put(_ghTokenKey, token);
  }

  static Future<void> clearGhToken() async {
    await _box.delete(_ghTokenKey);
  }
}
