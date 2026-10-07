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
  static bool _centralDesconectadaActual = false;

  // ==========================================================
  // CONTROL DEL CICLO Y CANCELACIÓN INMEDIATA
  // ==========================================================

  static int _ciclo = 0;

  // Completers activos para cancelar/desbloquear sin esperar timeouts
  static Completer<void>? _completerVozActual;
  static Completer<void>? _completerAudioActual;

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
  // HABLAR Y ESPERAR A QUE TERMINE (CON PREEMCIÓN INMEDIATA)
  // ==========================================================

  static Future<void> _hablarCompleto(String mensaje, int ciclo) async {
    if (ciclo != _ciclo) return;

    final completer = Completer<void>();
    _completerVozActual = completer;

    void completar() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    try {
      _tts.setCompletionHandler(() {
        if (_ciclo == ciclo) {
          completar();
        }
      });
      _tts.setCancelHandler(() {
        completar();
      });
      _tts.setErrorHandler((_) {
        completar();
      });

      if (ciclo != _ciclo) {
        completar();
        return;
      }

      await _tts.speak(mensaje);

      if (ciclo != _ciclo) {
        try {
          await _tts.stop();
        } catch (_) {}
        completar();
        return;
      }

      await completer.future.timeout(
        const Duration(seconds: 7),
        onTimeout: () {
          completar();
        },
      );
    } catch (_) {
      completar();
    } finally {
      if (_completerVozActual == completer) {
        _completerVozActual = null;
      }
    }
  }

  // ==========================================================
  // REPRODUCIR SONIDO COMPLETO (CON PREEMCIÓN INMEDIATA)
  // ==========================================================

  static Future<void> _reproducirSonidoCompleto(int ciclo) async {
    if (ciclo != _ciclo) return;

    final completer = Completer<void>();
    _completerAudioActual = completer;

    StreamSubscription? subscription;

    void completar() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    try {
      subscription = _audioPlayer.onPlayerComplete.listen((_) {
        if (_ciclo == ciclo) {
          completar();
        }
      });

      if (ciclo != _ciclo) {
        completar();
        return;
      }

      await _audioPlayer.play(
        AssetSource('audio/alerta_epp.mp3'),
      );

      if (ciclo != _ciclo) {
        try {
          await _audioPlayer.stop();
        } catch (_) {}
        completar();
        return;
      }

      await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          completar();
        },
      );
    } catch (_) {
      completar();
    } finally {
      try {
        await subscription?.cancel();
      } catch (_) {}
      if (_completerAudioActual == completer) {
        _completerAudioActual = null;
      }
    }
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
  // ACTUALIZAR TODOS LOS ESTADOS (LATEST EVENT WINS)
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

    final bool anteriorCentralDesconectada = _centralDesconectadaActual;

    final nuevosRetirados =
    Set<String>.from(retirados);

    final nuevosDesconectados =
    Set<String>.from(desconectados);

    // ========================================================
    // ¿CAMBIÓ ALGO?
    // Solo generamos nuevas alertas cuando existe una TRANSICIÓN real.
    // Si el estado permanece igual, NO recreamos el ciclo; el ciclo
    // repetitivo activo continúa su marcha de forma ininterrumpida.
    // ========================================================

    if (anteriorCentralDesconectada == centralDesconectada &&
        _mismosElementos(
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
    // INTERRUPCIÓN INMEDIATA (LATEST EVENT WINS)
    // 1. Desbloquear y resolver inmediatamente Completers activos
    // 2. Incrementar _ciclo para invalidar la alerta/bucle anterior
    // 3. Detener hardware TTS y AudioPlayer
    // ========================================================

    final Completer<void>? completerVozViejo = _completerVozActual;
    final Completer<void>? completerAudioViejo = _completerAudioActual;

    _completerVozActual = null;
    _completerAudioActual = null;

    if (completerVozViejo != null && !completerVozViejo.isCompleted) {
      completerVozViejo.complete();
    }
    if (completerAudioViejo != null && !completerAudioViejo.isCompleted) {
      completerAudioViejo.complete();
    }

    final int cicloActual = ++_ciclo;

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    try {
      await _tts.stop();
    } catch (_) {}

    // Si durante el stop llegó otra transición más reciente, salir
    if (cicloActual != _ciclo) {
      return;
    }

    // ========================================================
    // ACTUALIZAR ESTADOS
    // ========================================================

    _retiradosActuales = nuevosRetirados;
    _desconectadosActuales = nuevosDesconectados;
    _centralDesconectadaActual = centralDesconectada;

    // ========================================================
    // CASO ESPECIAL 1:
    // CASCO DESCONECTADO = SISTEMA COMPLETO DESCONECTADO
    // Problema crítico persistente: VOZ -> ALARMA -> VOZ -> ALARMA...
    // ========================================================

    if (centralDesconectada) {
      const mensajeCentral =
          'Sistema EPP desconectado por completo.';

      await showNotification(
        id: 500,
        title: '🚨 SISTEMA EPP DESCONECTADO',
        body: mensajeCentral,
      );

      // Lanzar ciclo repetitivo en segundo plano (VOZ -> ALARMA -> VOZ -> ALARMA...)
      unawaited(_ejecutarCicloProblema(
        mensaje: mensajeCentral,
        ciclo: cicloActual,
      ));

      return;
    }

    // ========================================================
    // CASO ESPECIAL 2:
    // CASCO SE RECONECTÓ (ESTABA DESCONECTADO Y AHORA NO)
    // ========================================================

    final bool cascoSeReconecto = anteriorCentralDesconectada && !centralDesconectada;

    // ========================================================
    // DETECTAR RECUPERACIONES (PUESTO O CONECTADO)
    // ========================================================

    final List<String> recuperadosColocados = [];
    final List<String> recuperadosConectados = [];

    // EQUIPOS QUE ESTABAN RETIRADOS Y YA NO LO ESTÁN NI ESTÁN DESCONECTADOS
    for (final equipo in anteriorRetirados) {
      if (!nuevosRetirados.contains(equipo) &&
          !nuevosDesconectados.contains(equipo)) {
        recuperadosColocados.add(equipo);
      }
    }

    // EQUIPOS QUE ESTABAN DESCONECTADOS Y AHORA ESTÁN CONECTADOS
    for (final equipo in anteriorDesconectados) {
      if (!nuevosDesconectados.contains(equipo)) {
        if (!nuevosRetirados.contains(equipo) &&
            !recuperadosColocados.contains(equipo)) {
          recuperadosConectados.add(equipo);
        }
      }
    }

    // ========================================================
    // ESCENARIO A: RECUPERACIÓN TOTAL (EPP COMPLETO Y CONECTADO)
    // Sin problemas pendientes. Anuncio UNA SOLA VEZ y silencio.
    // ========================================================

    if (nuevosRetirados.isEmpty && nuevosDesconectados.isEmpty) {
      final List<String> partesRecuperacion = [];

      if (cascoSeReconecto) {
        partesRecuperacion.add('Sistema conectado.');
      }

      if (recuperadosColocados.isNotEmpty) {
        partesRecuperacion.add(_crearMensajeColocados(recuperadosColocados));
      }

      if (recuperadosConectados.isNotEmpty) {
        partesRecuperacion.add(_crearMensajeReconectados(recuperadosConectados));
      }

      final String mensajeTodoBien;
      if (partesRecuperacion.isNotEmpty) {
        mensajeTodoBien =
            '${partesRecuperacion.join(' ')} Todos los equipos de protección están colocados y conectados.';
      } else {
        mensajeTodoBien =
            'Todos los equipos de protección están colocados y conectados.';
      }

      await showNotification(
        id: 500,
        title: '✅ EPP COMPLETO',
        body: mensajeTodoBien,
      );

      if (!_puedeContinuar(cicloActual)) {
        return;
      }

      // ANUNCIO ÚNICO: VOZ UNA VEZ, LUEGO SILENCIO
      await _hablarCompleto(mensajeTodoBien, cicloActual);
      return;
    }

    // ========================================================
    // ESCENARIO B: EXISTEN PROBLEMAS ACTIVOS (RETIRADO O DESCONECTADO)
    // ========================================================

    // Si hubo alguna recuperación puntual simultánea, anunciarla primero una vez
    final List<String> frasesRecuperacionPuntual = [];
    if (cascoSeReconecto) {
      frasesRecuperacionPuntual.add('Sistema conectado.');
    }
    if (recuperadosColocados.isNotEmpty) {
      frasesRecuperacionPuntual.add(_crearMensajeColocados(recuperadosColocados));
    }
    if (recuperadosConectados.isNotEmpty) {
      frasesRecuperacionPuntual.add(_crearMensajeReconectados(recuperadosConectados));
    }

    // Mensaje representativo del ESTADO PROBLEMÁTICO ACTUAL
    final String mensajeProblemaActual = _crearMensajeEstadoActual();

    final List<String> frasesIniciales = [];
    if (frasesRecuperacionPuntual.isNotEmpty) {
      frasesIniciales.addAll(frasesRecuperacionPuntual);
    }
    if (mensajeProblemaActual.isNotEmpty) {
      frasesIniciales.add(mensajeProblemaActual);
    }

    final String mensajeAlertaInicial = frasesIniciales.join(' ');

    if (mensajeAlertaInicial.isEmpty) {
      return;
    }

    // Mostrar notificación del evento
    await showNotification(
      id: 500,
      title: '🚨 ALERTA EPP',
      body: mensajeAlertaInicial,
    );

    // Lanzar ciclo repetitivo en segundo plano (VOZ -> ALARMA -> VOZ -> ALARMA...)
    // La primera locución puede incluir la recuperación puntual si la hubo,
    // y los ciclos subsiguientes repetirán el estado problemático actual.
    unawaited(_ejecutarCicloProblema(
      mensaje: mensajeProblemaActual.isNotEmpty ? mensajeProblemaActual : mensajeAlertaInicial,
      mensajeInicial: mensajeAlertaInicial,
      ciclo: cicloActual,
    ));
  }

  // ==========================================================
  // BUCLE REPETITIVO DE PROBLEMAS (VOZ -> ALARMA -> VOZ -> ALARMA)
  // Se ejecuta indefinidamente mientras el problema persista
  // y hasta que una nueva transición incremente _ciclo.
  // ==========================================================

  static Future<void> _ejecutarCicloProblema({
    required String mensaje,
    String? mensajeInicial,
    required int ciclo,
  }) async {
    bool primerPaso = true;

    while (_puedeContinuar(ciclo)) {
      final String textoAHablar = (primerPaso && mensajeInicial != null)
          ? mensajeInicial
          : mensaje;
      primerPaso = false;

      // 1. PRIMERO SIEMPRE VA LA VOZ
      await _hablarCompleto(textoAHablar, ciclo);

      if (!_puedeContinuar(ciclo)) {
        break;
      }

      // Pequeña pausa de inteligibilidad (500 ms)
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (!_puedeContinuar(ciclo)) {
        break;
      }

      // 2. DESPUÉS VA LA ALARMA
      await _reproducirSonidoCompleto(ciclo);

      if (!_puedeContinuar(ciclo)) {
        break;
      }

      // Pequeña pausa antes de volver a repetir la voz (1 segundo)
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  // ==========================================================
  // COMPROBAR CICLO
  // ==========================================================

  static bool _puedeContinuar(
      int cicloActual) {
    return _ciclo == cicloActual;
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
  // MENSAJE COLOCADOS
  // ==========================================================

  static String _crearMensajeColocados(
      List<String> lista) {

    if (lista.isEmpty) {
      return '';
    }

    final nombres = List<String>.from(lista);

    if (nombres.length == 1) {
      return '${nombres[0]} colocado.';
    }

    if (nombres.length == 2) {
      return '${nombres[0]} y '
          '${nombres[1]} colocados.';
    }

    final ultimo = nombres.removeLast();

    return '${nombres.join(', ')} '
        'y $ultimo colocados.';
  }

  // ==========================================================
  // MENSAJE RECONECTADOS
  // ==========================================================

  static String _crearMensajeReconectados(
      List<String> lista) {

    if (lista.isEmpty) {
      return '';
    }

    final nombres = List<String>.from(lista);

    if (nombres.length == 1) {
      return '${nombres[0]} conectado.';
    }

    if (nombres.length == 2) {
      return '${nombres[0]} y '
          '${nombres[1]} conectados.';
    }

    final ultimo = nombres.removeLast();

    return '${nombres.join(', ')} '
        'y $ultimo conectados.';
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
    final Completer<void>? completerVozViejo = _completerVozActual;
    final Completer<void>? completerAudioViejo = _completerAudioActual;

    _completerVozActual = null;
    _completerAudioActual = null;

    if (completerVozViejo != null && !completerVozViejo.isCompleted) {
      completerVozViejo.complete();
    }
    if (completerAudioViejo != null && !completerAudioViejo.isCompleted) {
      completerAudioViejo.complete();
    }

    _ciclo++;

    _retiradosActuales.clear();
    _desconectadosActuales.clear();
    _centralDesconectadaActual = false;

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

    final int cicloActual = ++_ciclo;

    await _hablarCompleto(body, cicloActual);

    await _reproducirSonidoCompleto(cicloActual);
  }
}