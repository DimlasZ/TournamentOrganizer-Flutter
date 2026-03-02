import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/tournament_provider.dart';

class PlayerManagerScreen extends StatelessWidget {
  const PlayerManagerScreen({super.key});

  void _showAddDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Add Player', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Player name',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
          ),
          onSubmitted: (v) {
            context.read<PlayerProvider>().addPlayer(v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<PlayerProvider>().addPlayer(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String id, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Edit Player', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.deepPurpleAccent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<PlayerProvider>().editPlayer(id, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Players', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, pp, _) {
          final players = pp.sortedPlayers;
          if (players.isEmpty) {
            return const Center(
              child: Text('No players yet.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            );
          }
          final tournament = context.watch<TournamentProvider>().activeTournament;
          final activeIds = tournament?.activePlayers ?? [];
          return ListView.builder(
            itemCount: players.length,
            itemBuilder: (ctx, i) {
              final p = players[i];
              final inTournament = activeIds.contains(p.id);
              return ListTile(
                title: Text(p.name, style: const TextStyle(color: Colors.white)),
                subtitle: inTournament
                    ? const Text('In active tournament', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 12))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                      onPressed: () => _showEditDialog(context, p.id, p.name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white38, size: 20),
                      onPressed: inTournament
                          ? null
                          : () => context.read<PlayerProvider>().deletePlayer(p.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurpleAccent,
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
