import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/tournament.dart';
import '../models/round.dart';
import '../models/match.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../logic/swiss_pairing.dart';
import '../logic/standings.dart';
import '../logic/bye_assignment.dart';
import '../services/storage_service.dart';

const _uuid = Uuid();

class TournamentProvider extends ChangeNotifier {
  Tournament? _active;
  List<Tournament> _past = [];

  Tournament? get activeTournament => _active;
  List<Tournament> get pastTournaments => List.unmodifiable(_past);

  bool get hasActiveTournament => _active != null;

  Future<void> init() async {
    _active = StorageService.loadActiveTournament();
    _past = StorageService.loadPastTournaments();
    notifyListeners();
  }

  Future<void> _save() async {
    await StorageService.saveActiveTournament(_active);
    await StorageService.savePastTournaments(_past);
    notifyListeners();
  }

  // --- Creation ---
  Future<void> createTournament(List<String> playerIds, String dateStr) async {
    _active = Tournament(
      id: _uuid.v4(),
      dateStr: dateStr,
      activePlayers: List.from(playerIds),
      seatingOrder: List.from(playerIds),
    );
    await _save();
  }

  Future<void> abandonTournament() async {
    _active = null;
    await _save();
  }

  // --- Seating ---
  Future<void> reshuffleSeating() async {
    if (_active == null || _active!.currentRound > 0) return;
    _active!.seatingOrder = shuffle(List<String>.from(_active!.activePlayers));
    await _save();
  }

  // --- Round Management ---
  Future<void> pairNextRound(List<Player> allPlayers) async {
    final t = _active;
    if (t == null) return;

    final standings = computeStandings(t.activePlayers, t.rounds, allPlayers);

    String? byePlayerId;
    if (t.activePlayers.length % 2 != 0) {
      byePlayerId = selectByePlayer(t.activePlayers, t.completedRounds, standings);
    }

    // Round 1: use seating order for fold-pair; later rounds: standings order so top players meet
    final playerList = t.completedRounds.isEmpty
        ? t.seatingOrder
        : standings.map((s) => s.playerId).toList();
    final matches = pairRound(playerList, t.completedRounds, byePlayerId);
    final round = Round(
      roundNumber: t.currentRound + 1,
      matches: matches,
    );
    t.rounds.add(round);
    t.currentRound = round.roundNumber;
    await _save();
  }

  Future<void> swapPlayers(String idA, String idB) async {
    final round = _active?.activeRound;
    if (round == null) return;
    for (final match in round.matches) {
      final p1IsA = match.player1Id == idA;
      final p1IsB = match.player1Id == idB;
      final p2IsA = match.player2Id == idA;
      final p2IsB = match.player2Id == idB;
      if (p1IsA || p2IsA || p1IsB || p2IsB) {
        // Swap within match or across matches handled by rebuilding pairings
        // Simple approach: rebuild active round pairings with swap
        break;
      }
    }
    // Find both matches and swap the players
    TournamentMatch? matchA;
    TournamentMatch? matchB;
    bool aIsP1 = false, bIsP1 = false;
    for (final m in round.matches) {
      if (m.player1Id == idA || m.player2Id == idA) {
        matchA = m;
        aIsP1 = m.player1Id == idA;
      }
      if (m.player1Id == idB || m.player2Id == idB) {
        matchB = m;
        bIsP1 = m.player1Id == idB;
      }
    }
    if (matchA == null || matchB == null) return;

    final idxA = round.matches.indexWhere((m) => m.id == matchA!.id);
    final idxB = round.matches.indexWhere((m) => m.id == matchB!.id);

    if (idxA == idxB) return; // same match

    // Build new matches with swapped players
    final newMatchA = TournamentMatch(
      id: matchA.id,
      player1Id: aIsP1 ? idB : matchA.player1Id,
      player2Id: aIsP1 ? matchA.player2Id : idB,
      isBye: matchA.isBye,
    );
    final newMatchB = TournamentMatch(
      id: matchB.id,
      player1Id: bIsP1 ? idA : matchB.player1Id,
      player2Id: bIsP1 ? matchB.player2Id : idA,
      isBye: matchB.isBye,
    );

    round.matches[idxA] = newMatchA;
    round.matches[idxB] = newMatchB;
    await _save();
  }

  Future<void> reassignBye(String newByePlayerId) async {
    final round = _active?.activeRound;
    if (round == null) return;
    // Remove old bye
    round.matches.removeWhere((m) => m.isBye);
    // Remove new bye player from their existing match and give them the bye
    final existingMatchIdx =
        round.matches.indexWhere((m) => m.player1Id == newByePlayerId || m.player2Id == newByePlayerId);
    if (existingMatchIdx >= 0) {
      final existing = round.matches[existingMatchIdx];
      final otherId = existing.player1Id == newByePlayerId ? existing.player2Id : existing.player1Id;
      round.matches.removeAt(existingMatchIdx);
      if (otherId != null) {
        // The displaced player gets a bye instead
        round.matches.add(TournamentMatch(id: _uuid.v4(), player1Id: otherId, isBye: true));
      }
    }
    round.matches.add(TournamentMatch(id: _uuid.v4(), player1Id: newByePlayerId, isBye: true));
    await _save();
  }

  Future<void> repairActiveRound(List<Player> allPlayers) async {
    final t = _active;
    if (t == null) return;
    final round = t.activeRound;
    if (round == null) return;
    if (round.matches.any((m) => m.result != null)) return; // has results, can't repair

    t.rounds.remove(round);
    t.currentRound = t.completedRounds.isEmpty ? 0 : t.completedRounds.last.roundNumber;
    await pairNextRound(allPlayers);
  }

  Future<void> completeCurrentRound() async {
    final round = _active?.activeRound;
    if (round == null) return;
    if (!round.allResultsEntered) return;

    // Auto-submit bye results
    for (final match in round.matches) {
      if (match.isBye && match.result == null) {
        match.result = MatchResult(
          player1Wins: 2,
          player2Wins: 0,
          draws: 0,
          submittedAt: DateTime.now(),
        );
      }
    }

    round.status = 'complete';
    await _save();
  }

  // --- Results ---
  Future<void> submitResult(
    String matchId, {
    required int player1Wins,
    required int player2Wins,
    required int draws,
  }) async {
    final round = _active?.activeRound;
    if (round == null) return;
    final matchIdx = round.matches.indexWhere((m) => m.id == matchId);
    if (matchIdx < 0) return;

    final existing = round.matches[matchIdx].result;
    round.matches[matchIdx].result = MatchResult(
      player1Wins: player1Wins,
      player2Wins: player2Wins,
      draws: draws,
      submittedAt: existing?.submittedAt ?? DateTime.now(),
      correctedAt: existing != null ? DateTime.now() : null,
    );
    await _save();
  }

  Future<void> editHistoryResult(
    int roundNumber,
    String matchId, {
    required int player1Wins,
    required int player2Wins,
    required int draws,
  }) async {
    final round = _active?.rounds.firstWhere(
      (r) => r.roundNumber == roundNumber,
      orElse: () => throw StateError('Round not found'),
    );
    if (round == null) return;
    final matchIdx = round.matches.indexWhere((m) => m.id == matchId);
    if (matchIdx < 0) return;
    round.matches[matchIdx].result = MatchResult(
      player1Wins: player1Wins,
      player2Wins: player2Wins,
      draws: draws,
      submittedAt: round.matches[matchIdx].result?.submittedAt ?? DateTime.now(),
      correctedAt: DateTime.now(),
    );
    await _save();
  }

  // --- Players ---
  Future<void> dropPlayer(String playerId) async {
    _active?.activePlayers.remove(playerId);
    _active?.droppedPlayers.add(playerId);
    await _save();
  }

  Future<void> addLateArrival(String playerId) async {
    if (_active == null) return;
    if (!_active!.activePlayers.contains(playerId)) {
      _active!.activePlayers.add(playerId);
      _active!.droppedPlayers.remove(playerId);
    }
    await _save();
  }

  // --- End ---
  Future<void> finishTournament() async {
    if (_active == null) return;
    _active!.status = 'complete';
    await _save();
  }

  // --- History ---
  Future<void> archiveCompleted() async {
    final t = _active;
    if (t == null || !t.isComplete) return;
    _past.insert(0, t);
    _active = null;
    await _save();
  }

  Future<void> reopenTournament(String tournamentId) async {
    final idx = _past.indexWhere((t) => t.id == tournamentId);
    if (idx < 0) return;
    _active = _past.removeAt(idx);
    _active!.status = 'active';
    await _save();
  }

  Future<void> deleteHistoryEntry(String tournamentId) async {
    _past.removeWhere((t) => t.id == tournamentId);
    await _save();
  }

  // --- Standings helper ---
  List<StandingsEntry> getStandings(List<Player> allPlayers) {
    final t = _active;
    if (t == null) return [];
    return computeStandings(t.activePlayers, t.rounds, allPlayers);
  }
}
