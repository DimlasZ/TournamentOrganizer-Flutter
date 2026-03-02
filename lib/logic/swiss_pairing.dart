import 'dart:math';
import '../models/match.dart';
import '../models/round.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

Set<String> buildPriorMatchups(List<Round> completedRounds) {
  final matchups = <String>{};
  for (final round in completedRounds) {
    for (final match in round.matches) {
      if (!match.isBye && match.player2Id != null) {
        final ids = [match.player1Id, match.player2Id!]..sort();
        matchups.add('${ids[0]}|${ids[1]}');
      }
    }
  }
  return matchups;
}

bool hasPlayed(String a, String b, Set<String> matchups) {
  final ids = [a, b]..sort();
  return matchups.contains('${ids[0]}|${ids[1]}');
}

List<TournamentMatch> pairRound(
  List<String> playerIds,
  List<Round> completedRounds,
  String? byePlayerId,
) {
  final players = List<String>.from(playerIds);
  if (byePlayerId != null) players.remove(byePlayerId);

  List<TournamentMatch> pairs;
  if (completedRounds.isEmpty) {
    pairs = _foldPair(players);
  } else {
    final matchups = buildPriorMatchups(completedRounds);
    pairs = _backtrackPair(players, matchups) ?? _greedyPair(players, matchups);
  }

  if (byePlayerId != null) {
    pairs.add(TournamentMatch(
      id: _uuid.v4(),
      player1Id: byePlayerId,
      isBye: true,
      result: null,
    ));
  }

  return pairs;
}

List<TournamentMatch> _foldPair(List<String> players) {
  // Seating order is already randomized — fold seat 1 vs seat n/2+1, etc.
  final half = players.length ~/ 2;
  final pairs = <TournamentMatch>[];
  for (int i = 0; i < half; i++) {
    pairs.add(TournamentMatch(
      id: _uuid.v4(),
      player1Id: players[i],
      player2Id: players[i + half],
    ));
  }
  return pairs;
}

List<TournamentMatch>? _backtrackPair(List<String> players, Set<String> matchups) {
  final result = <TournamentMatch>[];
  if (_bt(List<String>.from(players), matchups, result)) return result;
  return null;
}

bool _bt(List<String> remaining, Set<String> matchups, List<TournamentMatch> result) {
  if (remaining.isEmpty) return true;
  final first = remaining[0];
  for (int i = 1; i < remaining.length; i++) {
    final opponent = remaining[i];
    if (!hasPlayed(first, opponent, matchups)) {
      result.add(TournamentMatch(
        id: _uuid.v4(),
        player1Id: first,
        player2Id: opponent,
      ));
      final next = List<String>.from(remaining)
        ..removeAt(i)
        ..removeAt(0);
      if (_bt(next, matchups, result)) return true;
      result.removeLast();
    }
  }
  return false;
}

List<TournamentMatch> _greedyPair(List<String> players, Set<String> matchups) {
  final remaining = List<String>.from(players);
  final pairs = <TournamentMatch>[];
  while (remaining.length >= 2) {
    final first = remaining.removeAt(0);
    final opponentIdx = remaining.indexWhere((p) => !hasPlayed(first, p, matchups));
    final opponentI = opponentIdx >= 0 ? opponentIdx : 0;
    final opponent = remaining.removeAt(opponentI);
    pairs.add(TournamentMatch(
      id: _uuid.v4(),
      player1Id: first,
      player2Id: opponent,
    ));
  }
  return pairs;
}

List<T> shuffle<T>(List<T> list) {
  final rng = Random();
  for (int i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
  return list;
}
