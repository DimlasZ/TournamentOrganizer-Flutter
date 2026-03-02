import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../logic/standings.dart';
import '../models/match.dart';
import '../providers/player_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/tournament_provider.dart';
import '../services/csv_service.dart';
import '../services/github_service.dart';

class PairingsScreen extends StatefulWidget {
  const PairingsScreen({super.key});

  @override
  State<PairingsScreen> createState() => _PairingsScreenState();
}

class _PairingsScreenState extends State<PairingsScreen> {
  String? _swapSelectedId;
  bool _swapMode = false;

  @override
  void initState() {
    super.initState();
    final timer = context.read<TimerProvider>();
    timer.registerTaskDataCallback();
    timer.initServiceIfNeeded();
  }

  @override
  void dispose() {
    context.read<TimerProvider>().unregisterTaskDataCallback();
    super.dispose();
  }
  bool _showHistory = false;
  String? _editingMatchId;
  int? _editingRoundNum;

  static const _resultOptions = [
    (p1: 2, p2: 0, d: 0, label: '2-0'),
    (p1: 2, p2: 1, d: 0, label: '2-1'),
    (p1: 1, p2: 0, d: 0, label: '1-0'),
    (p1: 1, p2: 1, d: 0, label: '1-1'),
    (p1: 0, p2: 0, d: 0, label: '0-0'),
    (p1: 0, p2: 1, d: 0, label: '0-1'),
    (p1: 1, p2: 2, d: 0, label: '1-2'),
    (p1: 0, p2: 2, d: 0, label: '0-2'),
  ];

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TournamentProvider>();
    final pp = context.watch<PlayerProvider>();
    final timer = context.watch<TimerProvider>();
    final t = tp.activeTournament;

    if (t == null) return _buildNoTournament(context);
    if (t.isComplete) return _buildComplete(context, tp, pp);
    if (t.currentRound == 0) return _buildSeating(context, tp, pp, timer);

    final round = t.activeRound;
    if (round != null) return _buildActiveRound(context, tp, pp, timer);
    return _buildBetweenRounds(context, tp, pp, timer);
  }

  // ── No Tournament ──────────────────────────────────────────────
  Widget _buildNoTournament(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _appBar('Pairings'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_esports, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('No active tournament', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/tournament/setup'),
              style: FilledButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
              child: const Text('Create Tournament'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seating View ───────────────────────────────────────────────
  Widget _buildSeating(BuildContext context, TournamentProvider tp, PlayerProvider pp, TimerProvider timer) {
    final t = tp.activeTournament!;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _appBar('Round 1 — Seating'),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: t.seatingOrder.length,
              itemBuilder: (ctx, i) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(pp.nameOf(t.seatingOrder[i]), style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: tp.reshuffleSeating,
                  icon: const Icon(Icons.shuffle, color: Colors.white70),
                  label: const Text('Randomize Seating', style: TextStyle(color: Colors.white70)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    await tp.pairNextRound(pp.players);
                    timer.setDuration(65 * 60);
                    timer.startTimer();
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Round 1'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
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

  // ── Active Round ───────────────────────────────────────────────
  Widget _buildActiveRound(BuildContext context, TournamentProvider tp, PlayerProvider pp, TimerProvider timer) {
    final t = tp.activeTournament!;
    final round = t.activeRound!;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _appBar('Round ${round.roundNumber}', actions: [
        IconButton(
          icon: Icon(_swapMode ? Icons.close : Icons.swap_horiz, color: Colors.white70),
          tooltip: _swapMode ? 'Cancel swap' : 'Swap players',
          onPressed: () => setState(() { _swapMode = !_swapMode; _swapSelectedId = null; }),
        ),
      ]),
      body: Column(
        children: [
          _buildTimerBar(context, timer),
          if (_swapMode)
            Container(
              color: Colors.deepPurple.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _swapSelectedId == null
                    ? 'Tap a player to swap'
                    : 'Now tap the player to swap with',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.deepPurpleAccent),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...round.matches.map((m) => _buildMatchCard(context, tp, pp, m, round.roundNumber)),
                const SizedBox(height: 8),
                _buildRoundHistory(context, tp, pp),
              ],
            ),
          ),
          if (!_swapMode)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: round.allResultsEntered
                    ? () async {
                        await tp.completeCurrentRound();
                        timer.stopTimer();
                      }
                    : null,
                icon: const Icon(Icons.check),
                label: Text('Complete Round ${round.roundNumber}'),
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

  Widget _buildMatchCard(BuildContext context, TournamentProvider tp, PlayerProvider pp,
      TournamentMatch match, int roundNum) {
    final p1 = pp.nameOf(match.player1Id);
    final p2 = match.isBye ? 'BYE' : pp.nameOf(match.player2Id ?? '');
    final result = match.result;
    final isEditing = _editingMatchId == match.id && _editingRoundNum == roundNum;

    // Compute name/score colors based on result
    Color p1NameColor = Colors.white;
    Color p2NameColor = match.isBye ? Colors.white38 : Colors.white;
    Color scoreColor = Colors.white;
    if (result != null && !match.isBye) {
      final isDraw = result.player1Wins == result.player2Wins;
      if (isDraw) {
        p1NameColor = Colors.yellow;
        p2NameColor = Colors.yellow;
        scoreColor = Colors.yellow;
      } else if (result.player1Wins > result.player2Wins) {
        p1NameColor = Colors.green;
        p2NameColor = Colors.white70;
        scoreColor = Colors.green;
      } else {
        p1NameColor = Colors.white70;
        p2NameColor = Colors.green;
        scoreColor = Colors.green;
      }
    }

    return Card(
      color: const Color(0xFF1A2E4A),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: _swapMode
                      ? InkWell(
                          onTap: () => _handleSwapTap(context, tp, match.player1Id),
                          child: Text(p1,
                              style: TextStyle(
                                  color: _swapSelectedId == match.player1Id
                                      ? Colors.deepPurpleAccent
                                      : Colors.white,
                                  fontWeight: FontWeight.bold)),
                        )
                      : Text(p1, style: TextStyle(color: p1NameColor, fontWeight: FontWeight.bold)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('vs', style: TextStyle(color: Colors.white38)),
                ),
                Flexible(
                  child: _swapMode && !match.isBye && match.player2Id != null
                      ? InkWell(
                          onTap: () => _handleSwapTap(context, tp, match.player2Id!),
                          child: Text(p2,
                              style: TextStyle(
                                  color: _swapSelectedId == match.player2Id
                                      ? Colors.deepPurpleAccent
                                      : Colors.white,
                                  fontWeight: FontWeight.bold)),
                        )
                      : Text(p2,
                          style: TextStyle(
                              color: match.isBye ? Colors.white38 : p2NameColor,
                              fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (!match.isBye && !_swapMode) ...[
              const SizedBox(height: 10),
              if (result != null && !isEditing)
                Row(
                  children: [
                    Text(
                      '${result.player1Wins} – ${result.player2Wins}'
                      '${result.draws > 0 ? ' (${result.draws}d)' : ''}',
                      style: TextStyle(color: scoreColor, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() {
                        _editingMatchId = match.id;
                        _editingRoundNum = roundNum;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text('Edit', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                    ),
                  ],
                )
              else
                _buildResultButtons(context, tp, match, roundNum),
            ],
            if (match.isBye)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Auto 2-0 win', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultButtons(BuildContext context, TournamentProvider tp,
      TournamentMatch match, int roundNum) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _resultOptions.map((opt) {
        final current = match.result;
        final isSelected = current != null &&
            current.player1Wins == opt.p1 &&
            current.player2Wins == opt.p2 &&
            current.draws == opt.d;
        return InkWell(
          onTap: () async {
            await tp.submitResult(match.id,
                player1Wins: opt.p1, player2Wins: opt.p2, draws: opt.d);
            setState(() { _editingMatchId = null; _editingRoundNum = null; });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.deepPurpleAccent : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? Colors.deepPurpleAccent : Colors.white24,
              ),
            ),
            child: Text(opt.label,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }

  void _handleSwapTap(BuildContext context, TournamentProvider tp, String playerId) {
    if (_swapSelectedId == null) {
      setState(() => _swapSelectedId = playerId);
    } else if (_swapSelectedId == playerId) {
      setState(() => _swapSelectedId = null);
    } else {
      tp.swapPlayers(_swapSelectedId!, playerId);
      setState(() { _swapMode = false; _swapSelectedId = null; });
    }
  }

  // ── Between Rounds ─────────────────────────────────────────────
  Widget _buildBetweenRounds(BuildContext context, TournamentProvider tp, PlayerProvider pp, TimerProvider timer) {
    final t = tp.activeTournament!;
    final standings = tp.getStandings(pp.players);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _appBar('Round ${t.currentRound} Complete'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Standings preview
          const Text('Current Standings', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1)),
          const SizedBox(height: 8),
          ...standings.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text('${e.key + 1}.', style: const TextStyle(color: Colors.white54))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(pp.nameOf(e.value.playerId), style: const TextStyle(color: Colors.white))),
                    Text('${e.value.matchPoints} pts', style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              )),
          const SizedBox(height: 24),

          // Drop players
          ExpansionTile(
            title: const Text('Drop Players', style: TextStyle(color: Colors.white70)),
            iconColor: Colors.white54,
            collapsedIconColor: Colors.white54,
            children: t.activePlayers.map((id) => ListTile(
              title: Text(pp.nameOf(id), style: const TextStyle(color: Colors.white)),
              trailing: TextButton(
                onPressed: () => tp.dropPlayer(id),
                child: const Text('Drop', style: TextStyle(color: Colors.redAccent)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),

          _buildRoundHistory(context, tp, pp),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: () async {
              await tp.pairNextRound(pp.players);
              timer.setDuration(65 * 60);
              timer.startTimer();
            },
            icon: const Icon(Icons.arrow_forward),
            label: Text('Pair Round ${t.currentRound + 1}'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await tp.finishTournament();
              await tp.archiveCompleted();
              if (context.mounted) context.go('/standings');
            },
            icon: const Icon(Icons.flag, color: Colors.white70),
            label: const Text('Finish Tournament', style: TextStyle(color: Colors.white70)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tournament Complete ─────────────────────────────────────────
  Widget _buildComplete(BuildContext context, TournamentProvider tp, PlayerProvider pp) {
    final t = tp.activeTournament ?? tp.pastTournaments.first;
    final standings = computeStandingsForComplete(tp, pp);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _appBar('Tournament Complete'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: Icon(Icons.emoji_events, size: 72, color: Colors.amber)),
          const SizedBox(height: 8),
          if (standings.isNotEmpty)
            Center(child: Text(pp.nameOf(standings.first.playerId),
                style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 24),
          ...standings.asMap().entries.map((e) {
            final rank = e.key + 1;
            final s = e.value;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: rank == 1 ? Colors.amber : Colors.deepPurple,
                child: Text('$rank', style: const TextStyle(color: Colors.white)),
              ),
              title: Text(pp.nameOf(s.playerId), style: const TextStyle(color: Colors.white)),
              trailing: Text('${s.matchPoints} pts', style: const TextStyle(color: Colors.white54)),
            );
          }),
          const SizedBox(height: 24),
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
            onPressed: () => _showGitHubUpload(context, tp, pp, t),
            icon: const Icon(Icons.cloud_upload, color: Colors.white70),
            label: const Text('Upload to GitHub', style: TextStyle(color: Colors.white70)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 16),
          _buildRoundHistory(context, tp, pp),
        ],
      ),
    );
  }

  // ── Timer Bar ──────────────────────────────────────────────────
  Widget _buildTimerBar(BuildContext context, TimerProvider timer) {
    final isAlarm = timer.timerState == TimerState.alarm;
    final m = (timer.remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (timer.remainingSeconds % 60).toString().padLeft(2, '0');
    final isWarning = timer.remainingSeconds <= 10 * 60 && timer.remainingSeconds > 0;

    return Container(
      color: isAlarm ? Colors.red.withOpacity(0.2) : const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(isAlarm ? Icons.alarm_off : Icons.timer,
              color: isAlarm ? Colors.redAccent : Colors.white54, size: 20),
          const SizedBox(width: 8),
          Text(
            isAlarm ? 'TIME IS UP!' : '$m:$s',
            style: TextStyle(
              color: isAlarm ? Colors.redAccent : isWarning ? Colors.orange : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          if (isAlarm)
            TextButton(
              onPressed: timer.stopTimer,
              child: const Text('Dismiss', style: TextStyle(color: Colors.redAccent)),
            ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white24, size: 18),
            onPressed: () => _showTimerEdit(context, timer),
          ),
        ],
      ),
    );
  }

  void _showTimerEdit(BuildContext context, TimerProvider timer) {
    int mins = timer.remainingSeconds ~/ 60;
    int secs = timer.remainingSeconds % 60;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Set Timer', style: TextStyle(color: Colors.white)),
        content: Row(
          children: [
            Expanded(child: TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Min', labelStyle: TextStyle(color: Colors.white54)),
              controller: TextEditingController(text: '$mins'),
              onChanged: (v) => mins = int.tryParse(v) ?? mins,
            )),
            const SizedBox(width: 16),
            Expanded(child: TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Sec', labelStyle: TextStyle(color: Colors.white54)),
              controller: TextEditingController(text: '$secs'),
              onChanged: (v) => secs = int.tryParse(v) ?? secs,
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final newSecs = mins * 60 + secs;
              Navigator.pop(ctx);
              await timer.stopTimer();
              timer.setDuration(newSecs);
              await timer.startTimer();
            },
            child: const Text('Set', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );
  }

  // ── Round History ──────────────────────────────────────────────
  Widget _buildRoundHistory(BuildContext context, TournamentProvider tp, PlayerProvider pp) {
    final t = tp.activeTournament;
    if (t == null || t.completedRounds.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: const Text('Round History', style: TextStyle(color: Colors.white70)),
      initiallyExpanded: _showHistory,
      onExpansionChanged: (v) => setState(() => _showHistory = v),
      iconColor: Colors.white54,
      collapsedIconColor: Colors.white54,
      children: t.completedRounds.map((round) => ExpansionTile(
        title: Text('Round ${round.roundNumber}',
            style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white38,
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
        children: round.matches.map((m) {
            if (m.isBye) {
              return ListTile(
                dense: true,
                title: Text('${pp.nameOf(m.player1Id)} — BYE (2-0)',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              );
            }
            final r = m.result;
            final isEditing = _editingMatchId == m.id && _editingRoundNum == round.roundNumber;
            // History colors
            Color p1HColor = Colors.white70;
            Color p2HColor = Colors.white70;
            Color scoreHColor = Colors.white54;
            if (r != null) {
              final isDraw = r.player1Wins == r.player2Wins;
              if (isDraw) {
                p1HColor = Colors.yellow;
                p2HColor = Colors.yellow;
                scoreHColor = Colors.yellow;
              } else if (r.player1Wins > r.player2Wins) {
                p1HColor = Colors.green;
                scoreHColor = Colors.green;
              } else {
                p2HColor = Colors.green;
                scoreHColor = Colors.green;
              }
            }
            return ListTile(
              dense: true,
              title: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13),
                  children: [
                    TextSpan(text: pp.nameOf(m.player1Id), style: TextStyle(color: p1HColor)),
                    const TextSpan(text: ' vs ', style: TextStyle(color: Colors.white38)),
                    TextSpan(text: pp.nameOf(m.player2Id ?? ''), style: TextStyle(color: p2HColor)),
                  ],
                ),
              ),
              trailing: isEditing
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r != null ? '${r.player1Wins}-${r.player2Wins}' : '—',
                            style: TextStyle(color: scoreHColor, fontSize: 13)),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16, color: Colors.white38),
                          onPressed: () => setState(() {
                            _editingMatchId = m.id;
                            _editingRoundNum = round.roundNumber;
                          }),
                        ),
                      ],
                    ),
              subtitle: isEditing
                  ? Wrap(
                      spacing: 4,
                      children: _resultOptions.map((opt) => InkWell(
                        onTap: () async {
                          await tp.editHistoryResult(round.roundNumber, m.id,
                              player1Wins: opt.p1, player2Wins: opt.p2, draws: opt.d);
                          setState(() { _editingMatchId = null; _editingRoundNum = null; });
                          final activeRound = tp.activeTournament?.activeRound;
                          if (context.mounted && activeRound != null &&
                              !activeRound.matches.any((mx) => mx.result != null)) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('Result corrected. Redo current round pairings?'),
                              action: SnackBarAction(
                                label: 'Redo',
                                onPressed: () async {
                                  final pp2 = context.read<PlayerProvider>();
                                  await tp.repairActiveRound(pp2.players);
                                },
                              ),
                              duration: const Duration(seconds: 5),
                            ));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(opt.label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      )).toList(),
                    )
                  : null,
            );
          }).toList(),
      )).toList(),
    );
  }

  // ── GitHub Upload ──────────────────────────────────────────────
  void _showGitHubUpload(BuildContext context, TournamentProvider tp, PlayerProvider pp, tournament) {
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
              final t = tp.activeTournament ?? tp.pastTournaments.first;
              final csv = CsvService.generateCsv(t, pp.players);
              final filename = CsvService.exportFilename(t.dateStr);
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

  // ── Helpers ────────────────────────────────────────────────────
  AppBar _appBar(String title, {List<Widget>? actions}) => AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        actions: actions,
      );

  List<StandingsEntry> computeStandingsForComplete(TournamentProvider tp, PlayerProvider pp) {
    final t = tp.activeTournament;
    if (t != null) return computeStandings(t.activePlayers, t.rounds, pp.players);
    if (tp.pastTournaments.isNotEmpty) {
      final past = tp.pastTournaments.first;
      return computeStandings(past.activePlayers, past.rounds, pp.players);
    }
    return [];
  }
}
