import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void timerTaskCallback() {
  FlutterForegroundTask.setTaskHandler(TimerTaskHandler());
}

class TimerTaskHandler extends TaskHandler {
  int _remainingSeconds = 0;
  bool _isRunning = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final saved = await FlutterForegroundTask.getData<int>(key: 'remainingSeconds');
    _remainingSeconds = saved ?? 0;
    _isRunning = true;
    _sendTick();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (!_isRunning || _remainingSeconds <= 0) return;

    _remainingSeconds--;
    _sendTick();

    if (_remainingSeconds == 40 * 60) {
      FlutterForegroundTask.sendDataToMain({'event': 'MILESTONE_40'});
    } else if (_remainingSeconds == 20 * 60) {
      FlutterForegroundTask.sendDataToMain({'event': 'MILESTONE_20'});
    } else if (_remainingSeconds == 0) {
      _isRunning = false;
      FlutterForegroundTask.sendDataToMain({'event': 'ALARM'});
      FlutterForegroundTask.updateService(
        notificationTitle: 'Timer',
        notificationText: 'Time is up!',
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    FlutterForegroundTask.sendDataToMain({'event': 'STOPPED'});
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      final event = data['event'] as String?;
      if (event == 'PAUSE') _isRunning = false;
      if (event == 'RESUME') _isRunning = true;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop') FlutterForegroundTask.stopService();
  }

  void _sendTick() {
    FlutterForegroundTask.sendDataToMain({
      'event': 'TICK',
      'remainingSeconds': _remainingSeconds,
    });

    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    FlutterForegroundTask.updateService(
      notificationTitle: 'Timer Running',
      notificationText: '$m:$s remaining',
    );
  }
}
