import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/tournament_provider.dart';
import 'screens/history_screen.dart';
import 'screens/pairings_screen.dart';
import 'screens/player_manager_screen.dart';
import 'screens/standings_screen.dart';
import 'screens/tournament_setup_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await StorageService.init();
  runApp(const TournamentApp());
}

final _router = GoRouter(
  initialLocation: '/tournament/setup',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithTabs(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/players', builder: (_, _) => const PlayerManagerScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/tournament/setup', builder: (_, _) => const TournamentSetupScreen()),
          GoRoute(path: '/tournament/pairings', builder: (_, _) => const PairingsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/standings', builder: (_, _) => const StandingsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
        ]),
      ],
    ),
  ],
);

class TournamentApp extends StatelessWidget {
  const TournamentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()..init()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()..init()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
      ],
      child: MaterialApp.router(
        title: 'Tournament Organizer',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
      ),
    );
  }
}

class _ScaffoldWithTabs extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldWithTabs({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF111111),
        indicatorColor: Colors.deepPurple.withOpacity(0.4),
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Players',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: 'Tournament',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Standings',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
