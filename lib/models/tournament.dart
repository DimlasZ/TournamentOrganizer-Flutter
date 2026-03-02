import 'round.dart';

class Tournament {
  final String id;
  final String dateStr; // "YYYY-MM-DD"
  String status; // "active" | "complete"
  int currentRound; // 0 = not started
  final List<String> activePlayers;
  final List<String> droppedPlayers;
  List<String> seatingOrder;
  final List<Round> rounds;

  Tournament({
    required this.id,
    required this.dateStr,
    this.status = 'active',
    this.currentRound = 0,
    required this.activePlayers,
    List<String>? droppedPlayers,
    List<String>? seatingOrder,
    List<Round>? rounds,
  })  : droppedPlayers = droppedPlayers ?? [],
        seatingOrder = seatingOrder ?? List.from(activePlayers),
        rounds = rounds ?? [];

  bool get isComplete => status == 'complete';

  Round? get activeRound {
    if (rounds.isEmpty) return null;
    final r = rounds.lastWhere((r) => r.status == 'active', orElse: () => rounds.last);
    return r.status == 'active' ? r : null;
  }

  Round? get latestRound => rounds.isEmpty ? null : rounds.last;

  List<Round> get completedRounds => rounds.where((r) => r.isComplete).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateStr': dateStr,
        'status': status,
        'currentRound': currentRound,
        'activePlayers': activePlayers,
        'droppedPlayers': droppedPlayers,
        'seatingOrder': seatingOrder,
        'rounds': rounds.map((r) => r.toJson()).toList(),
      };

  factory Tournament.fromJson(Map<String, dynamic> j) => Tournament(
        id: j['id'] as String,
        dateStr: j['dateStr'] as String,
        status: j['status'] as String,
        currentRound: j['currentRound'] as int,
        activePlayers: List<String>.from(j['activePlayers'] as List),
        droppedPlayers: List<String>.from(j['droppedPlayers'] as List? ?? []),
        seatingOrder: List<String>.from(j['seatingOrder'] as List? ?? []),
        rounds: (j['rounds'] as List? ?? [])
            .map((r) => Round.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList(),
      );
}
