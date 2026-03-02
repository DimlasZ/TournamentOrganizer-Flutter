# TournamentOrganizer — Flutter

An Android app for running Swiss-format card game tournaments. Built in Flutter with a background foreground service so the round timer keeps firing alarm sounds even when the phone is locked.

---

## Features

### Player Management
- Add, edit, and delete players with persistent local storage
- Automatically syncs the player roster from a remote CSV (ManaCore) on startup
- Merges remote players with local additions

### Tournament Setup
- Select which players are participating
- Set the tournament date
- Randomize seating order before Round 1

### Swiss Pairing
- **Round 1:** fold-pair based on seating order (seat 1 vs seat 5, 2 vs 6, etc.)
- **Round 2+:** standings-ordered backtracking pairing — top players face each other, rematches avoided
- Greedy fallback if backtracking finds no solution
- Bye assignment: lowest-ranked player without a previous bye receives it; rotates if all have had one
- Manual swap mode: tap any two players to swap their pairings (works even after results are entered)
- Reassign bye to a different player

### Round Timer
- 65-minute countdown displayed on the pairings screen
- Runs as an Android Foreground Service — alarm sounds fire at 40 min, 20 min, and 0 (loops) even on a locked screen
- Timer can be manually adjusted mid-round
- Dismiss button stops the alarm when time is up

### Match Results
- Eight result buttons per match: `2-0`, `2-1`, `1-0`, `1-1`, `0-0`, `0-1`, `1-2`, `0-2`
- Results can be edited at any time during the round
- Round history: all completed rounds are collapsible; individual match results can be corrected
- After correcting a past result, the app offers to redo the current round's pairings if no results have been entered yet

### Standings & Tiebreakers
Full MTG tiebreaker system after every completed round:

| Tiebreaker | Description |
|---|---|
| **Points** | 3 for win, 1 for draw, 0 for loss |
| **OMW%** | Average match-win % of all opponents (each opponent floored at 33%) |
| **GW%** | Player's own game-win percentage (raw, no floor) |
| **OGW%** | Average game-win % of all opponents (each opponent floored at 33%) |

Byes count as a 2-0 match win but the bye round is excluded from opponent lists.

### Export & Upload
- **Download CSV:** exports all match results as a `.csv` file and shares it via the system share sheet
- **Upload to GitHub:** pushes the CSV directly to `results/` in this repository using a GitHub Personal Access Token (stored securely on-device)

CSV format:
```
draws,player1,player1Wins,player2,player2Wins,round,tournamentDate
```

### Tournament History
- Completed tournaments are archived and viewable in the History tab
- Individual past tournaments can be reopened (if a correction is needed) or deleted

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State management | Provider (`ChangeNotifier`) |
| Navigation | go_router (bottom tab bar + stack) |
| Local storage | Hive |
| Background timer | flutter_foreground_task |
| Alarm sounds | just_audio |
| CSV sharing | share_plus + path_provider |
| GitHub upload | http (GitHub Contents API) |
| IDs | uuid |

---

## Project Structure

```
lib/
├── main.dart                        go_router setup, MultiProvider, tab scaffold
├── models/                          Player, TournamentMatch, Round, Tournament, MatchResult
├── logic/
│   ├── swiss_pairing.dart           fold-pair, backtracking, greedy, shuffle
│   ├── standings.dart               MTG tiebreaker computation
│   └── bye_assignment.dart          lowest-ranked player without a bye
├── providers/
│   ├── player_provider.dart         player CRUD + remote CSV sync
│   ├── tournament_provider.dart     full tournament lifecycle
│   └── timer_provider.dart          foreground service wrapper
├── services/
│   ├── storage_service.dart         Hive box wrappers
│   ├── github_service.dart          GitHub Contents API PUT
│   ├── csv_service.dart             CSV generation + share_plus export
│   ├── alarm_player.dart            audio playback
│   └── timer_foreground_task.dart   foreground service task handler
└── screens/
    ├── player_manager_screen.dart
    ├── tournament_setup_screen.dart
    ├── pairings_screen.dart          timer + match cards + round management
    ├── standings_screen.dart         tiebreaker table
    └── history_screen.dart
```

---

## GitHub Upload Setup

1. Create a GitHub Personal Access Token with **Contents — Read and write** permission for this repository
2. In the app, go to Standings → Upload to GitHub
3. Paste the token — it is stored on-device and reused for future uploads
4. The CSV is written to `results/YYYY_MM_DD_matches.csv`
