import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/tournament_provider.dart';
import '../logic/standings.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TournamentProvider>();
    final pp = context.watch<PlayerProvider>();
    final past = tp.pastTournaments;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('History', style: TextStyle(color: Colors.white)),
      ),
      body: past.isEmpty
          ? const Center(
              child: Text('No past tournaments', style: TextStyle(color: Colors.white54, fontSize: 16)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: past.length,
              itemBuilder: (ctx, i) {
                final t = past[i];
                final standings = computeStandings(t.activePlayers, t.rounds, pp.players);
                final winner = standings.isNotEmpty ? pp.nameOf(standings.first.playerId) : '—';
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(t.dateStr,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(winner, style: const TextStyle(color: Colors.amber, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${t.activePlayers.length} players · ${t.completedRounds.length} rounds',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: tp.hasActiveTournament
                                  ? null
                                  : () => _confirmReopen(ctx, tp, t.id),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.deepPurpleAccent),
                                foregroundColor: Colors.deepPurpleAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text('Reopen'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _confirmDelete(ctx, tp, t.id),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmReopen(BuildContext context, TournamentProvider tp, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Reopen Tournament?', style: TextStyle(color: Colors.white)),
        content: const Text('This will restore the tournament as your active tournament.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              tp.reopenTournament(id);
              Navigator.pop(ctx);
            },
            child: const Text('Reopen', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, TournamentProvider tp, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Entry?', style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              tp.deleteHistoryEntry(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
