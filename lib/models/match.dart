import 'match_result.dart';

class TournamentMatch {
  final String id;
  final String player1Id;
  final String? player2Id;
  final bool isBye;
  MatchResult? result;

  TournamentMatch({
    required this.id,
    required this.player1Id,
    this.player2Id,
    this.isBye = false,
    this.result,
  });

  TournamentMatch copyWith({
    String? id,
    String? player1Id,
    String? player2Id,
    bool? isBye,
    MatchResult? result,
  }) =>
      TournamentMatch(
        id: id ?? this.id,
        player1Id: player1Id ?? this.player1Id,
        player2Id: player2Id ?? this.player2Id,
        isBye: isBye ?? this.isBye,
        result: result ?? this.result,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'player1Id': player1Id,
        'player2Id': player2Id,
        'isBye': isBye,
        'result': result?.toJson(),
      };

  factory TournamentMatch.fromJson(Map<String, dynamic> j) => TournamentMatch(
        id: j['id'] as String,
        player1Id: j['player1Id'] as String,
        player2Id: j['player2Id'] as String?,
        isBye: (j['isBye'] as bool?) ?? false,
        result: j['result'] != null
            ? MatchResult.fromJson(Map<String, dynamic>.from(j['result'] as Map))
            : null,
      );
}
