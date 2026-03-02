class MatchResult {
  final int player1Wins;
  final int player2Wins;
  final int draws;
  final DateTime submittedAt;
  final DateTime? correctedAt;

  const MatchResult({
    required this.player1Wins,
    required this.player2Wins,
    required this.draws,
    required this.submittedAt,
    this.correctedAt,
  });

  Map<String, dynamic> toJson() => {
        'player1Wins': player1Wins,
        'player2Wins': player2Wins,
        'draws': draws,
        'submittedAt': submittedAt.toIso8601String(),
        'correctedAt': correctedAt?.toIso8601String(),
      };

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        player1Wins: j['player1Wins'] as int,
        player2Wins: j['player2Wins'] as int,
        draws: j['draws'] as int,
        submittedAt: DateTime.parse(j['submittedAt'] as String),
        correctedAt: j['correctedAt'] != null
            ? DateTime.parse(j['correctedAt'] as String)
            : null,
      );
}
