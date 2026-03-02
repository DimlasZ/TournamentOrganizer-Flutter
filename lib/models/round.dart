import 'match.dart';

class Round {
  final int roundNumber;
  String status; // "active" | "complete"
  final List<TournamentMatch> matches;

  Round({
    required this.roundNumber,
    this.status = 'active',
    required this.matches,
  });

  bool get isComplete => status == 'complete';
  bool get allResultsEntered => matches.every((m) => m.result != null);

  Map<String, dynamic> toJson() => {
        'roundNumber': roundNumber,
        'status': status,
        'matches': matches.map((m) => m.toJson()).toList(),
      };

  factory Round.fromJson(Map<String, dynamic> j) => Round(
        roundNumber: j['roundNumber'] as int,
        status: j['status'] as String,
        matches: (j['matches'] as List)
            .map((m) => TournamentMatch.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}
