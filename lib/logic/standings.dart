import '../models/round.dart';
import '../models/player.dart';

const double _floor = 0.3333;

class StandingsEntry {
  final String playerId;
  final int matchPoints;
  final int matchWins;
  final int matchLosses;
  final int matchDraws;
  final int gamesWon;
  final int gamesLost;
  final int gamesPlayed;
  final double mwPct;
  final double gwPct;
  final double omwPct;
  final double ogwPct;
  final bool hasBye;
  final List<String> opponents;

  const StandingsEntry({
    required this.playerId,
    required this.matchPoints,
    required this.matchWins,
    required this.matchLosses,
    required this.matchDraws,
    required this.gamesWon,
    required this.gamesLost,
    required this.gamesPlayed,
    required this.mwPct,
    required this.gwPct,
    required this.omwPct,
    required this.ogwPct,
    required this.hasBye,
    required this.opponents,
  });
}

List<StandingsEntry> computeStandings(
  List<String> activePlayers,
  List<Round> rounds,
  List<Player> allPlayers,
) {
  final completedRounds = rounds.where((r) => r.isComplete).toList();

  // First pass: build raw stats per player
  final stats = <String, Map<String, dynamic>>{};
  for (final id in activePlayers) {
    stats[id] = {
      'matchPoints': 0,
      'matchWins': 0,
      'matchLosses': 0,
      'matchDraws': 0,
      'gamesWon': 0,
      'gamesLost': 0,
      'gamesPlayed': 0,
      'hasBye': false,
      'opponents': <String>[],
    };
  }

  for (final round in completedRounds) {
    for (final match in round.matches) {
      if (!activePlayers.contains(match.player1Id)) continue;

      if (match.isBye) {
        final s = stats[match.player1Id]!;
        s['matchPoints'] = (s['matchPoints'] as int) + 3;
        s['matchWins'] = (s['matchWins'] as int) + 1;
        s['gamesWon'] = (s['gamesWon'] as int) + 2;
        s['gamesPlayed'] = (s['gamesPlayed'] as int) + 2;
        s['hasBye'] = true;
        continue;
      }

      final r = match.result;
      if (r == null) continue;
      final p2 = match.player2Id;
      if (p2 == null || !activePlayers.contains(p2)) continue;

      final s1 = stats[match.player1Id]!;
      final s2 = stats[p2]!;

      // Determine winner/loser/draw
      if (r.player1Wins > r.player2Wins) {
        s1['matchPoints'] = (s1['matchPoints'] as int) + 3;
        s1['matchWins'] = (s1['matchWins'] as int) + 1;
        s2['matchLosses'] = (s2['matchLosses'] as int) + 1;
      } else if (r.player2Wins > r.player1Wins) {
        s2['matchPoints'] = (s2['matchPoints'] as int) + 3;
        s2['matchWins'] = (s2['matchWins'] as int) + 1;
        s1['matchLosses'] = (s1['matchLosses'] as int) + 1;
      } else {
        s1['matchPoints'] = (s1['matchPoints'] as int) + 1;
        s2['matchPoints'] = (s2['matchPoints'] as int) + 1;
        s1['matchDraws'] = (s1['matchDraws'] as int) + 1;
        s2['matchDraws'] = (s2['matchDraws'] as int) + 1;
      }

      s1['gamesWon'] = (s1['gamesWon'] as int) + r.player1Wins;
      s1['gamesLost'] = (s1['gamesLost'] as int) + r.player2Wins;
      s1['gamesPlayed'] = (s1['gamesPlayed'] as int) + r.player1Wins + r.player2Wins + r.draws;

      s2['gamesWon'] = (s2['gamesWon'] as int) + r.player2Wins;
      s2['gamesLost'] = (s2['gamesLost'] as int) + r.player1Wins;
      s2['gamesPlayed'] = (s2['gamesPlayed'] as int) + r.player1Wins + r.player2Wins + r.draws;

      (s1['opponents'] as List<String>).add(p2);
      (s2['opponents'] as List<String>).add(match.player1Id);
    }
  }

  // Compute mwPct and gwPct per player
  double mwPct(String id) {
    final s = stats[id]!;
    final total = (s['matchWins'] as int) + (s['matchLosses'] as int) + (s['matchDraws'] as int);
    if (total == 0) return _floor;
    final raw = (s['matchPoints'] as int) / (total * 3.0);
    return raw < _floor ? _floor : raw;
  }

  double gwPct(String id) {
    final s = stats[id]!;
    final played = s['gamesPlayed'] as int;
    if (played == 0) return _floor;
    final raw = (s['gamesWon'] as int) / played.toDouble();
    return raw < _floor ? _floor : raw;
  }

  // Second pass: compute OMW% and OGW%
  final entries = <StandingsEntry>[];
  for (final id in activePlayers) {
    final s = stats[id]!;
    final opponents = s['opponents'] as List<String>;

    double omw = _floor;
    double ogw = _floor;
    if (opponents.isNotEmpty) {
      omw = opponents.map(mwPct).reduce((a, b) => a + b) / opponents.length;
      ogw = opponents.map(gwPct).reduce((a, b) => a + b) / opponents.length;
      if (omw < _floor) omw = _floor;
      if (ogw < _floor) ogw = _floor;
    }

    entries.add(StandingsEntry(
      playerId: id,
      matchPoints: s['matchPoints'] as int,
      matchWins: s['matchWins'] as int,
      matchLosses: s['matchLosses'] as int,
      matchDraws: s['matchDraws'] as int,
      gamesWon: s['gamesWon'] as int,
      gamesLost: s['gamesLost'] as int,
      gamesPlayed: s['gamesPlayed'] as int,
      mwPct: mwPct(id),
      gwPct: gwPct(id),
      omwPct: omw,
      ogwPct: ogw,
      hasBye: s['hasBye'] as bool,
      opponents: opponents,
    ));
  }

  // Sort: Points → OMW% → GW% → OGW%
  entries.sort((a, b) {
    if (b.matchPoints != a.matchPoints) return b.matchPoints.compareTo(a.matchPoints);
    if (b.omwPct != a.omwPct) return b.omwPct.compareTo(a.omwPct);
    if (b.gwPct != a.gwPct) return b.gwPct.compareTo(a.gwPct);
    return b.ogwPct.compareTo(a.ogwPct);
  });

  return entries;
}
