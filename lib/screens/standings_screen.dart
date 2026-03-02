import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/standings.dart';
import '../providers/player_provider.dart';
import '../providers/tournament_provider.dart';
import '../services/csv_service.dart';
import '../services/github_service.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TournamentProvider>();
    final pp = context.watch<PlayerProvider>();

    // Prefer active tournament; fall back to most recent past tournament
    final t = tp.activeTournament ??
        (tp.pastTournaments.isNotEmpty ? tp.pastTournaments.first : null);

    if (t == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Standings', style: TextStyle(color: Colors.white))),
        body: const Center(
          child: Text('No tournament data', style: TextStyle(color: Colors.white54, fontSize: 16)),
        ),
      );
    }

    final standings = computeStandings(t.activePlayers, t.rounds, pp.players);
    final completedCount = t.completedRounds.length;
    final isComplete = t.isComplete;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Standings', style: TextStyle(color: Colors.white)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              completedCount == 0 ? 'No rounds completed' : 'After Round $completedCount',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ),
      ),
      body: standings.isEmpty
          ? const Center(child: Text('No data yet', style: TextStyle(color: Colors.white54)))
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFF1E1E1E)),
                          dataRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFF1A1A1A)),
                          columnSpacing: 8,
                          columns: const [
                            DataColumn(label: Text('#', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Player', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Pts', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('W-L-D', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('OMW%', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('GW%', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('OGW%', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                          ],
                          rows: standings.asMap().entries.map((entry) {
                            final rank = entry.key + 1;
                            final s = entry.value;
                            final name = pp.nameOf(s.playerId);
                            final isChamp = isComplete && rank == 1;
                            return DataRow(
                              color: WidgetStateProperty.all(
                                  isChamp ? const Color(0xFF2d1f00) : Colors.transparent),
                              cells: [
                                DataCell(Text('$rank', style: TextStyle(color: isChamp ? Colors.amber : Colors.white70))),
                                DataCell(Text(name, style: TextStyle(color: isChamp ? Colors.amber : Colors.white, fontWeight: isChamp ? FontWeight.bold : FontWeight.normal))),
                                DataCell(Text('${s.matchPoints}', style: TextStyle(color: isChamp ? Colors.amber : Colors.white))),
                                DataCell(Text('${s.matchWins}-${s.matchLosses}-${s.matchDraws}', style: const TextStyle(color: Colors.white70))),
                                DataCell(Text('${(s.omwPct * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70))),
                                DataCell(Text('${(s.gwPct * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70))),
                                DataCell(Text('${(s.ogwPct * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isComplete)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            final csv = CsvService.generateCsv(t, pp.players);
                            final filename = CsvService.exportFilename(t.dateStr);
                            await CsvService.shareCsv(filename, csv);
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Download CSV'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            minimumSize: const Size(double.infinity, 52),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showGitHubUpload(context, t, pp),
                          icon: const Icon(Icons.cloud_upload, color: Colors.white70),
                          label: const Text('Upload to GitHub', style: TextStyle(color: Colors.white70)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white38),
                            minimumSize: const Size(double.infinity, 52),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  void _showGitHubUpload(BuildContext context, tournament, PlayerProvider pp) {
    final existingToken = GitHubService.getStoredToken();
    final ctrl = TextEditingController(text: existingToken ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Upload to GitHub', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your GitHub Personal Access Token:',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'ghp_...',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final token = ctrl.text.trim();
              if (token.isEmpty) return;
              Navigator.pop(ctx);
              await GitHubService.setStoredToken(token);
              final csv = CsvService.generateCsv(tournament, pp.players);
              final filename = CsvService.exportFilename(tournament.dateStr);
              final result = await GitHubService.pushResults(filename, csv, token);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
              }
            },
            child: const Text('Upload', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );
  }
}
