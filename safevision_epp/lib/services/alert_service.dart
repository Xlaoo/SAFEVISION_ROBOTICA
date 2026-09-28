import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AlertService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static final FlutterTts _tts = FlutterTts();

  static bool _initialized = false;

  // ==========================================================
  // ESTADOS ACTUALES
  // ==========================================================

  static Set<String> _retiradosActuales = {};
  static Set<String> _desconectadosActuales = {};

  // ==========================================================
  // CONTROL DEL CICLO
  // ==========================================================

  static int _ciclo = 0;

  static bool _alertaActiva = false;

  // ==========================================================
  // INICIALIZAR
  // ==========================================================

  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
    InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: settings,
    );

    // ========================================================
    // VOZ
    // ========================================================

    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // ========================================================
    // AUDIO
    // ========================================================

    await _audioPlayer.setVolume(1.0);

    _initialized = true;
  }

  // ==========================================================
  // HABLAR Y ESPERAR A QUE TERMINE
  // ==========================================================

  static Future<void> _hablarCompleto(String mensaje) async {
    try {
      final completer = Completer<void>();

      void completar() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }

      _tts.setCompletionHandler(completar);
      _tts.setCancelHandler(completar);
      _tts.setErrorHandler((_) {
        completar();
      });

      await _tts.stop();

      await _tts.speak(mensaje);

      await completer.future;
    } catch (_) {}
  }

  // ==========================================================
  // REPRODUCIR SONIDO COMPLETO
  // ==========================================================

  static Future<void> _reproducirSonidoCompleto() async {
    try {
      final completer = Completer<void>();

      late StreamSubscription subscription;

      subscription = _audioPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await _audioPlayer.stop();

      await _audioPlayer.play(
        AssetSource('audio/alerta_epp.mp3'),
      );

      await completer.future;

      await subscription.cancel();
    } catch (_) {}
  }

  // ==========================================================
  // NOTIFICACIÓN
  // ==========================================================

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'safevision_alertas',
      'Alertas SafeVisionEPP',
      channelDescription:
      'Alertas de seguridad de equipos EPP',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
    );

    const NotificationDetails details =
    NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // ==========================================================
  // ACTUALIZAR TODOS LOS ESTADOS
  // ==========================================================

  static Future<void> actualizarEstado({
    required Set<String> retirados,
    required Set<String> desconectados,
    required bool centralDesconectada,
  }) async {
    await initialize();

    final anteriorRetirados =
    Set<String>.from(_retiradosActuales);

    final anteriorDesconectados =
    Set<String>.from(_desconectadosActuales);

    final nuevosRetirados =
    Set<String>.from(retirados);

    final nuevosDesconectados =
    Set<String>.from(desconectados);

    // ========================================================
    // ¿CAMBIÓ ALGO?
    // ========================================================

    if (_mismosElementos(
      anteriorRetirados,
      nuevosRetirados,
    ) &&
        _mismosElementos(
          anteriorDesconectados,
          nuevosDesconectados,
        )) {
      return;
    }

    // ========================================================
    // INVALIDAR CICLO ANTERIOR
    // ========================================================

    _ciclo++;

    final int cicloActual = _ciclo;

    _alertaActiva = false;

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    try {
      await _tts.stop();
    } catch (_) {}

    // ========================================================
    // ACTUALIZAR ESTADOS
    // ========================================================

    _retiradosActuales = nuevosRetirados;
    _desconectadosActuales = nuevosDesconectados;

    // ========================================================
    // CASO ESPECIAL:
    // CASCO DESCONECTADO = SISTEMA COMPLETO DESCONECTADO
    // ========================================================

    if (centralDesconectada) {
      _alertaActiva = true;

      const mensajeCentral =
          'Sistema EPP desconectado por completo.';

      await _hablarCompleto(mensajeCentral);

      if (!_puedeContinuar(cicloActual)) {
        return;
      }

      await showNotification(
        id: 500,
        title: '🚨 SISTEMA EPP DESCONECTADO',
        body: mensajeCentral,
      );

      unawaited(
        _ejecutarCiclo(
          cicloActual,
          mensajeCentral,
        ),
      );

      return;
    }

    // ========================================================
    // DETECTAR CAMBIOS
    // ========================================================

    final List<String> conectados = [];

    final List<String> nuevosRetiradosDetectados = [];

    final List<String> nuevosDesconectadosDetectados = [];

    // --------------------------------------------------------
    // EQUIPOS QUE ESTABAN RETIRADOS Y YA NO
    // --------------------------------------------------------

    for (final equipo in anteriorRetirados) {
      if (!nuevosRetirados.contains(equipo) &&
          !nuevosDesconectados.contains(equipo)) {
        conectados.add(equipo);
      }
    }

    // --------------------------------------------------------
    // EQUIPOS QUE ESTABAN DESCONECTADOS Y YA NO
    // --------------------------------------------------------

    for (final equipo in anteriorDesconectados) {
      if (!nuevosDesconectados.contains(equipo) &&
          !nuevosRetirados.contains(equipo) &&
          !conectados.contains(equipo)) {
        conectados.add(equipo);
      }
    }

    // --------------------------------------------------------
    // NUEVOS RETIRADOS
    // --------------------------------------------------------

    for (final equipo in nuevosRetirados) {
      if (!anteriorRetirados.contains(equipo)) {
        nuevosRetiradosDetectados.add(equipo);
      }
    }

    // --------------------------------------------------------
    // NUEVOS DESCONECTADOS
    // --------------------------------------------------------

    for (final equipo in nuevosDesconectados) {
      if (!anteriorDesconectados.contains(equipo)) {
        nuevosDesconectadosDetectados.add(equipo);
      }
    }

    // ========================================================
    // TODO CORRECTO
    // ========================================================

    if (nuevosRetirados.isEmpty &&
        nuevosDesconectados.isEmpty) {
      _alertaActiva = false;

      if (conectados.isNotEmpty) {
        await _hablarCompleto(
          '${_crearMensajeColocados(conectados)} '
              'Todos los equipos de protección están '
              'colocados y conectados.',
        );
      } else {
        await _hablarCompleto(
          'Todos los equipos de protección están '
              'colocados y conectados.',
        );
      }

      return;
    }

    // ========================================================
    // HAY INCIDENCIAS
    // ========================================================

    _alertaActiva = true;

    // ========================================================
    // PRIMERO: DECIR QUÉ SE SOLUCIONÓ
    // ========================================================

    if (conectados.isNotEmpty) {
      await _hablarCompleto(
        _crearMensajeColocados(conectados),
      );

      if (!_puedeContinuar(cicloActual)) {
        return;
      }
    }

    // ========================================================
    // SEGUNDO: DECIR NUEVOS RETIRADOS
    // ========================================================

    if (nuevosRetiradosDetectados.isNotEmpty) {
      await _hablarCompleto(
        _crearMensajeRetirados(
          nuevosRetiradosDetectados,
        ),
      );

      if (!_puedeContinuar(cicloActual)) {
        return;
      }
    }

    // ========================================================
    // TERCERO: DECIR NUEVOS DESCONECTADOS
    // ========================================================

    if (nuevosDesconectadosDetectados.isNotEmpty) {
      await _hablarCompleto(
        _crearMensajeDesconectados(
          nuevosDesconectadosDetectados,
        ),
      );

      if (!_puedeContinuar(cicloActual)) {
        return;
      }
    }

    // ========================================================
    // MENSAJE COMPLETO DE LA SITUACIÓN ACTUAL
    // ========================================================

    final mensajeActual =
    _crearMensajeEstadoActual();

    if (mensajeActual.isNotEmpty) {
      await _hablarCompleto(mensajeActual);

      if (!_puedeContinuar(cicloActual)) {
        return;
      }
    }

    // ========================================================
    // NOTIFICACIÓN
    // ========================================================

    await showNotification(
      id: 500,
      title: '🚨 ALERTA EPP',
      body: mensajeActual,
    );

    // ========================================================
    // COMENZAR CICLO
    // ========================================================

    unawaited(
      _ejecutarCiclo(
        cicloActual,
        mensajeActual,
      ),
    );
  }

  // ==========================================================
  // CICLO DE ALARMA
  //
  // VOZ → ALARMA → VOZ → ALARMA...
  // ==========================================================

  static Future<void> _ejecutarCiclo(
      int cicloActual,
      String mensaje,
      ) async {
    while (_puedeContinuar(cicloActual)) {

      // ======================================================
      // SONIDO
      // ======================================================

      await _reproducirSonidoCompleto();

      if (!_puedeContinuar(cicloActual)) {
        break;
      }

      // ======================================================
      // VOZ
      // ======================================================

      final mensajeActual =
      _crearMensajeEstadoActual();

      if (mensajeActual.isEmpty) {
        break;
      }

      await _hablarCompleto(mensajeActual);

      if (!_puedeContinuar(cicloActual)) {
        break;
      }
    }
  }

  // ==========================================================
  // COMPROBAR CICLO
  // ==========================================================

  static bool _puedeContinuar(
      int cicloActual) {
    return _alertaActiva &&
        _ciclo == cicloActual &&
        (_retiradosActuales.isNotEmpty ||
            _desconectadosActuales.isNotEmpty);
  }

  // ==========================================================
  // CREAR MENSAJE DEL ESTADO ACTUAL
  // ==========================================================

  static String _crearMensajeEstadoActual() {
    final partes = <String>[];

    if (_retiradosActuales.isNotEmpty) {
      partes.add(
        _crearMensajeRetirados(
          _retiradosActuales.toList(),
        ),
      );
    }

    if (_desconectadosActuales.isNotEmpty) {
      partes.add(
        _crearMensajeDesconectados(
          _desconectadosActuales.toList(),
        ),
      );
    }

    return partes.join(' ');
  }

  // ==========================================================
  // MENSAJE RETIRADOS
  // ==========================================================

  static String _crearMensajeRetirados(
      List<String> lista) {

    if (lista.isEmpty) {
      return '';
    }

    final nombres = List<String>.from(lista);

    if (nombres.length == 1) {
      return '${nombres[0]} retirado.';
    }

    if (nombres.length == 2) {
      return '${nombres[0]} y '
          '${nombres[1]} retirados.';
    }

    final ultimo = nombres.removeLast();

    return '${nombres.join(', ')} '
        'y $ultimo retirados.';
  }

  // ==========================================================
  // MENSAJE DESCONECTADOS
  // ==========================================================

  static String _crearMensajeDesconectados(
      List<String> lista) {

    if (lista.isEmpty) {
      return '';
    }

    final nombres = List<String>.from(lista);

    if (nombres.length == 1) {
      return '${nombres[0]} desconectado.';
    }

    if (nombres.length == 2) {
      return '${nombres[0]} y '
          '${nombres[1]} desconectados.';
    }

    final ultimo = nombres.removeLast();

    return '${nombres.join(', ')} '
        'y $ultimo desconectados.';
  }

  // ==========================================================
  // MENSAJE COLOCADOS / CONECTADOS
  // ==========================================================

  static String _crearMensajeColocados(
      List<String> lista) {

    if (lista.isEmpty) {
      return '';
    }

    final nombres = List<String>.from(lista);

    if (nombres.length == 1) {
      return '${nombres[0]} colocado y conectado.';
    }

    if (nombres.length == 2) {
      return '${nombres[0]} y '
          '${nombres[1]} colocados y conectados.';
    }

    final ultimo = nombres.removeLast();

    return '${nombres.join(', ')} '
        'y $ultimo colocados y conectados.';
  }

  // ==========================================================
  // COMPARAR SETS
  // ==========================================================

  static bool _mismosElementos(
      Set<String> a,
      Set<String> b) {

    if (a.length != b.length) {
      return false;
    }

    return a.containsAll(b);
  }

  // ==========================================================
  // DETENER ALERTA
  // ==========================================================

  static Future<void> detenerAlertas() async {
    _ciclo++;

    _alertaActiva = false;

    _retiradosActuales.clear();
    _desconectadosActuales.clear();

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    try {
      await _tts.stop();
    } catch (_) {}
  }

  // ==========================================================
  // DETENER TODO
  // ==========================================================

  static Future<void> stopAll() async {
    await detenerAlertas();
  }

  // ==========================================================
  // COMPATIBILIDAD
  // ==========================================================

  static Future<void> triggerAlert({
    required String title,
    required String body,
  }) async {
    await initialize();

    await _hablarCompleto(body);

    await _reproducirSonidoCompleto();
  }
}