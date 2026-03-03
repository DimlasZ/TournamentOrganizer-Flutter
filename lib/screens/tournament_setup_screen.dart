import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/tournament_provider.dart';

class TournamentSetupScreen extends StatefulWidget {
  const TournamentSetupScreen({super.key});

  @override
  State<TournamentSetupScreen> createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen> {
  final Set<String> _selected = {};
  DateTime _date = DateTime.now();

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.deepPurpleAccent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _startTournament(TournamentProvider tp) async {
    if (_selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 players')),
      );
      return;
    }
    await tp.createTournament(_selected.toList(), _dateStr);
    if (mounted) context.go('/tournament/pairings');
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TournamentProvider>();
    final pp = context.watch<PlayerProvider>();

    if (tp.hasActiveTournament) return _buildActiveTournamentView(context, tp);
    return _buildSetupView(context, tp, pp);
  }

  Widget _buildActiveTournamentView(BuildContext context, TournamentProvider tp) {
    final t = tp.activeTournament!;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Tournament', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 64, color: Colors.deepPurpleAccent),
              const SizedBox(height: 16),
              Text(
                'Tournament in Progress',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(t.dateStr, style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 4),
              Text('${t.activePlayers.length} players · Round ${t.currentRound}',
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.go('/tournament/pairings'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Go to Rounds'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  minimumSize: const Size(200, 52),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmAbandon(context, tp),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text('Abandon Tournament', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  minimumSize: const Size(200, 52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAbandon(BuildContext context, TournamentProvider tp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Abandon Tournament?', style: TextStyle(color: Colors.white)),
        content: const Text('This will discard the current tournament. This cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              tp.abandonTournament();
              Navigator.pop(ctx);
            },
            child: const Text('Abandon', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupView(BuildContext context, TournamentProvider tp, PlayerProvider pp) {
    final players = pp.sortedPlayers;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('New Tournament', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
            label: Text(_dateStr, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('${_selected.length} selected',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: players.isEmpty
                ? const Center(
                    child: Text('No players. Add some in the Players tab.',
                        style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (ctx, i) {
                      final p = players[i];
                      final checked = _selected.contains(p.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(p.id);
                          } else {
                            _selected.remove(p.id);
                          }
                        }),
                        title: Text(p.name, style: const TextStyle(color: Colors.white)),
                        activeColor: Colors.deepPurpleAccent,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _selected.length >= 2 ? () => _startTournament(tp) : null,
              icon: const Icon(Icons.play_arrow),
              label: Text('Start Tournament (${_selected.length} players)'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
