import '../models/round.dart';
import 'standings.dart';

/// Returns the playerId who should receive the bye this round.
/// Gives bye to lowest-ranked player who hasn't had one yet.
/// If all players have had a bye, picks the lowest-ranked overall.
String selectByePlayer(
  List<String> playerIds,
  List<Round> completedRounds,
  List<StandingsEntry> standings,
) {
  // Build set of players who already have a bye
  final hadBye = <String>{};
  for (final round in completedRounds) {
    for (final match in round.matches) {
      if (match.isBye) hadBye.add(match.player1Id);
    }
  }

  // Get standings order (lowest ranked = last)
  final orderedIds = standings.map((e) => e.playerId).toList();
  // Add any players not yet in standings (no rounds played)
  for (final id in playerIds) {
    if (!orderedIds.contains(id)) orderedIds.add(id);
  }

  // Try players who haven't had a bye, starting from lowest rank
  for (int i = orderedIds.length - 1; i >= 0; i--) {
    final id = orderedIds[i];
    if (playerIds.contains(id) && !hadBye.contains(id)) return id;
  }

  // All players had a bye — give to lowest-ranked overall
  for (int i = orderedIds.length - 1; i >= 0; i--) {
    final id = orderedIds[i];
    if (playerIds.contains(id)) return id;
  }

  return playerIds.last;
}
