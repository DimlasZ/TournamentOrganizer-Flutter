import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/alarm_player.dart';
import '../services/timer_foreground_task.dart';

enum TimerState { idle, running, alarm }

class TimerProvider extends ChangeNotifier {
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  TimerState _state = TimerState.idle;
  final AlarmPlayer _alarmPlayer = AlarmPlayer();

  int get totalSeconds => _totalSeconds;
  int get remainingSeconds => _remainingSeconds;
  TimerState get timerState => _state;

  void registerTaskDataCallback() {
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  void unregisterTaskDataCallback() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
  }

  void _onReceiveTaskData(Object data) {
    if (data is! Map<String, dynamic>) return;

    switch (data['event'] as String?) {
      case 'TICK':
        _remainingSeconds = (data['remainingSeconds'] as int?) ?? _remainingSeconds;
        notifyListeners();
        break;
      case 'ALARM':
        _remainingSeconds = 0;
        _state = TimerState.alarm;
        _alarmPlayer.play();
        notifyListeners();
        break;
      case 'MILESTONE_40':
        _alarmPlayer.playOnce('sounds/40_min_left.mp3');
        break;
      case 'MILESTONE_20':
        _alarmPlayer.playOnce('sounds/20_min_left.mp3');
        break;
      case 'STOPPED':
        _state = TimerState.idle;
        notifyListeners();
        break;
    }
  }

  void setDuration(int seconds) {
    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    notifyListeners();
  }

  // Call once at app start (from PairingsScreen initState)
  void initServiceIfNeeded() {
    if (_totalSeconds == 0) {
      _totalSeconds = 65 * 60;
      _remainingSeconds = 65 * 60;
    }
    initService();
  }

  void initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'timer_channel',
        channelName: 'Timer Notifications',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> startTimer() async {
    if (_remainingSeconds <= 0) return;

    await FlutterForegroundTask.saveData(
      key: 'remainingSeconds',
      value: _remainingSeconds,
    );

    final result = await FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: 'Timer Running',
      notificationText: _formatTime(_remainingSeconds),
      notificationButtons: [
        const NotificationButton(id: 'btn_stop', text: 'Stop'),
      ],
      callback: timerTaskCallback,
    );

    if (result is ServiceRequestSuccess) {
      _state = TimerState.running;
      notifyListeners();
    }
  }

  Future<void> stopTimer() async {
    await _alarmPlayer.stop();
    await FlutterForegroundTask.stopService();
    _state = TimerState.idle;
    _remainingSeconds = _totalSeconds;
    notifyListeners();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _alarmPlayer.dispose();
    super.dispose();
  }
}
