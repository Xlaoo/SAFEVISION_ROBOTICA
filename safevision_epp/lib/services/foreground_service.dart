import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
export 'package:flutter_foreground_task/flutter_foreground_task.dart' show WithForegroundTask;

// Callback requerido por flutter_foreground_task para el callback de segundo plano
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SafeVisionTaskHandler());
}

class SafeVisionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Tarea iniciada en segundo plano
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Evento de repetición
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Tarea destruida
  }
}

class ForegroundServiceManager {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'safevision_foreground_service',
        channelName: 'SAFE VISION EPP - Monitoreo Activo',
        channelDescription:
            'Servicio en primer plano para supervisión continua de equipos EPP con pantalla bloqueada.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _initialized = true;
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    await initialize();

    // Solicitar permiso de notificación en Android 13+ si no está concedido
    final NotificationPermission permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'SAFE VISION EPP',
      notificationText: 'Monitoreo activo de equipos EPP (Casco, Chaleco, Lentes)',
      notificationIcon: null,
      callback: startCallback,
    );
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    }
  }
}
