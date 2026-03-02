import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/tournament.dart';
import '../models/player.dart';

class CsvService {
  static String exportFilename(String dateStr) {
    return '${dateStr.replaceAll('-', '_')}_matches.csv';
  }

  static String generateCsv(Tournament tournament, List<Player> allPlayers) {
    final playerMap = {for (final p in allPlayers) p.id: p.name};

    final rows = <String>['draws,player1,player1Wins,player2,player2Wins,round,tournamentDate'];

    for (final round in tournament.rounds) {
      for (final match in round.matches) {
        if (match.isBye || match.result == null || match.player2Id == null) continue;
        final r = match.result!;
        final p1 = playerMap[match.player1Id] ?? match.player1Id;
        final p2 = playerMap[match.player2Id] ?? match.player2Id!;
        rows.add('${r.draws},$p1,${r.player1Wins},$p2,${r.player2Wins},'
            '${round.roundNumber},${tournament.dateStr}');
      }
    }

    return rows.join('\n');
  }

  static Future<void> shareCsv(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], text: filename);
  }
}
