import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/alert_service.dart';
import 'services/esp32_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AlertService.initialize();

  runApp(const SafeVisionEppApp());
}

// ============================================================
// APLICACIÓN
// ============================================================

class SafeVisionEppApp extends StatelessWidget {
  const SafeVisionEppApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeVisionEPP',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F8),
      ),
      home: const DashboardPage(),
    );
  }
}

// ============================================================
// MODELO DE IMPLEMENTO
// ============================================================

class EppItem {
  final String nombre;
  final String estado;
  final int incidencias;
  final int desconexiones;
  final String conexion;
  final String tipo;

  EppItem({
    required this.nombre,
    required this.estado,
    required this.incidencias,
    required this.desconexiones,
    required this.conexion,
    required this.tipo,
  });

  factory EppItem.fromJson(
      String nombre,
      Map<String, dynamic> json,
      ) {
    return EppItem(
      nombre: nombre,
      estado: json['estado']?.toString().trim().toUpperCase() ?? 'DESCONOCIDO',
      incidencias: json['incidencias'] ?? 0,
      desconexiones: json['desconexiones'] ?? 0,
      conexion: json['conexion']?.toString().trim().toUpperCase() ?? 'DESCONECTADO',
      tipo: json['tipo']?.toString().trim().toUpperCase() ?? 'SECUNDARIO',
    );
  }
}

// ============================================================
// MODELO DEL ESTADO GENERAL
// ============================================================

class EstadoEpp {
  final DateTime fechaHora;
  final String estadoSistema;
  final String central;

  final EppItem casco;
  final EppItem chaleco;
  final EppItem lentes;
  final EppItem guanteIzquierdo;
  final EppItem guanteDerecho;
  final EppItem botaIzquierda;
  final EppItem botaDerecha;

  final int totalIncidencias;
  final int totalDesconexiones;

  EstadoEpp({
    required this.fechaHora,
    required this.estadoSistema,
    required this.central,
    required this.casco,
    required this.chaleco,
    required this.lentes,
    required this.guanteIzquierdo,
    required this.guanteDerecho,
    required this.botaIzquierda,
    required this.botaDerecha,
    required this.totalIncidencias,
    required this.totalDesconexiones,
  });

  factory EstadoEpp.fromJson(Map<String, dynamic> json) {
    return EstadoEpp(
      fechaHora:
      DateTime.tryParse(json['fechaHora']?.toString() ?? '') ??
          DateTime.now(),

      estadoSistema:
      json['sistema']?['estado']?.toString() ?? 'DESCONECTADO',

      central:
      json['sistema']?['central']?.toString() ?? 'CASCO',

      casco: EppItem.fromJson(
        'Casco',
        json['casco'] ?? {},
      ),

      chaleco: EppItem.fromJson(
        'Chaleco',
        json['chaleco'] ?? {},
      ),

      lentes: EppItem.fromJson(
        'Lentes',
        json['lentes'] ?? {},
      ),

      guanteIzquierdo: EppItem.fromJson(
        'Guante izquierdo',
        json['guanteIzquierdo'] ?? {},
      ),

      guanteDerecho: EppItem.fromJson(
        'Guante derecho',
        json['guanteDerecho'] ?? {},
      ),

      botaIzquierda: EppItem.fromJson(
        'Bota izquierda',
        json['botaIzquierda'] ?? {},
      ),

      botaDerecha: EppItem.fromJson(
        'Bota derecha',
        json['botaDerecha'] ?? {},
      ),

      totalIncidencias:
      json['totalIncidencias'] ?? 0,

      totalDesconexiones:
      json['totalDesconexiones'] ?? 0,
    );
  }
}
// ============================================================
// MODELO DE HISTORIAL DE INCIDENCIA
// ============================================================

class IncidenciaEpp {
  final String nombre;
  final String estado;
  final DateTime fechaHora;

  IncidenciaEpp({
    required this.nombre,
    required this.estado,
    required this.fechaHora,
  });
}
// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState
    extends State<DashboardPage> {

  // ==========================================================
  // URL DE NUESTRA API
  // ==========================================================
  EstadoEpp? datos;

  bool cargando = true;
  bool conectado = false;

  String errorMensaje = '';

  Timer? timer;

  Timer? relojTimer;

  DateTime horaActual = DateTime.now();

  final Map<String, IncidenciaEpp> _incidenciasActivas = {};

  bool _consultaEnCurso = false;
  int _idConsultaActual = 0;
  bool _sistemaSeConecto = false;
  final Map<String, int> _contadorIncidencias = {};

  final Map<String, int> _contadorDesconexiones = {};

  int _desconexionSistema = 0;
  int _fallosConsecutivosCasco = 0;
  int _fallosConsecutivosChaleco = 0;
  int _fallosConsecutivosLentes = 0;


// ==========================================================
// ESTADO ANTERIOR
// ==========================================================
//
// Sirve para detectar TRANSICIONES.
//
// Si permanece retirado:
//     NO vuelve a sumar.
//
// Si vuelve a puesto y después se retira:
//     SUMA OTRA INCIDENCIA.
//
// ==========================================================

  Map<String, String> _estadosAnteriores = {};

  Map<String, String> _conexionesAnteriores = {};

  bool? _sistemaConectadoAnterior;


// ==========================================================
// CONTROL DE PRIMERA LECTURA
// ==========================================================
//
// La primera lectura NO cuenta como desconexión ni incidencia.
// Solo empezamos a contar cuando ocurre un CAMBIO.
// ==========================================================

  bool _primeraLectura = true;


// ==========================================================
// FECHA DEL CONTADOR
// ==========================================================

  String _fechaContadores = '';
  @override
  void initState() {
    super.initState();

    horaActual = DateTime.now();

    _inicializarYActualizar();

    // Actualizar datos de la API cada 3 segundos
    timer = Timer.periodic(
      const Duration(seconds: 3),
          (_) {
        actualizarDatos();
      },
    );

    // Reloj de la aplicación cada segundo
    relojTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted) return;

        setState(() {
          horaActual = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    relojTimer?.cancel();
    super.dispose();
  }

  // ==========================================================
  // CONSULTAR API
  // ==========================================================
// ==========================================================
// PROCESAR ALERTAS DE SEGURIDAD
// ==========================================================
// ==========================================================
// PROCESAR ALERTAS DE SEGURIDAD
// ==========================================================
  Future<void> _inicializarYActualizar() async {

    await _inicializarContadores();

    if (!mounted) {
      return;
    }

    await actualizarDatos();
  }
  Future<void> _procesarAlertas(
      EstadoEpp estado,
      ) async {

    final Set<String> retirados = {};
    final Set<String> desconectados = {};

    // ==========================================================
    // EL CASCO ES LA CENTRAL DEL SISTEMA
    // ==========================================================

    final bool cascoConectado =
        estado.casco.conexion.toUpperCase() == 'CONECTADO';


    // ==========================================================
    // CASO 1:
    // CASCO APAGADO / CENTRAL DESCONECTADA
    //
    // ESTO SE EJECUTA INCLUSO CUANDO LA APP
    // RECIÉN SE ABRE.
    // ==========================================================

    if (!cascoConectado) {

      print('');
      print('========================================');
      print('🚨 SISTEMA EPP APAGADO');
      print('========================================');
      print('🪖 CASCO: DESCONECTADO');
      print('🦺 CHALECO: DESCONECTADO');
      print('👓 LENTES: DESCONECTADO');
      print('🧤 GUANTES: DESCONECTADOS');
      print('👢 BOTAS: DESCONECTADAS');
      print('========================================');


      // ========================================================
      // TODO EL SISTEMA ESTÁ DESCONECTADO
      // ========================================================

      desconectados.add('Casco');
      desconectados.add('Chaleco');
      desconectados.add('Lentes');
      desconectados.add('Guante izquierdo');
      desconectados.add('Guante derecho');
      desconectados.add('Bota izquierda');
      desconectados.add('Bota derecha');


      // ========================================================
      // ALERTA CENTRAL
      //
      // IMPORTANTE:
      // AlertService será quien reproduzca:
      //
      // VOZ
      // SONIDO
      // VOZ
      // SONIDO
      // ...
      //
      // Y además la NOTIFICACIÓN.
      // ========================================================

      await AlertService.actualizarEstado(

        retirados: {},

        desconectados: desconectados,

        centralDesconectada: true,
      );


      return;
    }


    // ==========================================================
    // CASO 2:
    // CASCO ENCENDIDO
    // ==========================================================

    _sistemaSeConecto = true;


    print('');
    print('========================================');
    print('🟢 CENTRAL CASCO CONECTADA');
    print('========================================');


    // ==========================================================
    // CASCO
    // ==========================================================

    if (
    estado.casco.estado.toUpperCase() ==
        'RETIRADO'
    ) {

      retirados.add('Casco');

    }


    // ==========================================================
    // CHALECO
    // ==========================================================

    if (
    estado.chaleco.conexion.toUpperCase() !=
        'CONECTADO'
    ) {

      desconectados.add('Chaleco');

    } else if (
    estado.chaleco.estado.toUpperCase() ==
        'RETIRADO'
    ) {

      retirados.add('Chaleco');

    }


    // ==========================================================
    // LENTES
    // ==========================================================

    if (
    estado.lentes.conexion.toUpperCase() !=
        'CONECTADO'
    ) {

      desconectados.add('Lentes');

    } else if (
    estado.lentes.estado.toUpperCase() ==
        'RETIRADO'
    ) {

      retirados.add('Lentes');

    }


    // ==========================================================
    // GUANTE IZQUIERDO
    // ==========================================================

    if (
    estado.guanteIzquierdo.conexion.toUpperCase() !=
        'CONECTADO'
    ) {

      desconectados.add('Guante izquierdo');

    } else if (
    estado.guanteIzquierdo.estado.toUpperCase() ==
        'RETIRADO'
    ) {

      retirados.add('Guante izquierdo');

    }


    // ==========================================================
    // GUANTE DERECHO
    // ==========================================================

    if (
    estado.guanteDerecho.conexion.toUpperCase() !=
        'CONECTADO'
    ) {

      desconectados.add('Guante derecho');

    } else if (
    estado.guanteDerecho.estado.toUpperCase() ==
        'RETIRADO'
    ) {

      retirados.add('Guante derecho');

    }


    // ==========================================================
    // BOTA IZQUIERDA
    // ==========================================================

    if (
    estado.botaIzquierda.conexion.toUpperCase() !=
        'CONECTADO'
    ) {

      desconectados.add('Bota izquierda');

    } else if (
    estado.botaIzquierda.estado.toUpperCase() ==
        'RETIRADO'
    ) {

      retirados.add('Bota izquierda');

    }


    // ==========================================================
    // BOTA DERECHA
    // ==========================================================

    if (
    estado.botaDerecha.conexion.toUpperCase() !=
        'CONECTADO'
    ) {

      desconectados.add('Bota derecha');

    } else if (
    estado.botaDerecha.estado.toUpperCase() ==
        'RETIRADO'
    ) {

      retirados.add('Bota derecha');

    }


    // ==========================================================
    // ENVIAR ESTADO AL SERVICIO DE ALERTAS
    // ==========================================================

    print('');
    print('========================================');
    print('🔔 ESTADO DE ALERTAS');
    print('========================================');

    print(
      'Retirados: $retirados',
    );

    print(
      'Desconectados: $desconectados',
    );

    print('========================================');


    await AlertService.actualizarEstado(

      retirados: retirados,

      desconectados: desconectados,

      centralDesconectada: false,
    );
  }
  // ==========================================================
// ACTUALIZAR HISTORIAL DE INCIDENCIAS
// ==========================================================

  void _actualizarHistorialIncidencias(EstadoEpp estado) {

    final DateTime ahora = DateTime.now();

    // El casco es la central.
    final bool centralDesconectada =
        estado.casco.conexion.toUpperCase() != 'CONECTADO';

    final List<EppItem> equipos = [
      estado.casco,
      estado.chaleco,
      estado.lentes,
      estado.guanteIzquierdo,
      estado.guanteDerecho,
      estado.botaIzquierda,
      estado.botaDerecha,
    ];

    for (final item in equipos) {

      String estadoIncidencia;

      // ========================================================
      // PRIORIDAD 1: DESCONECTADO
      // ========================================================

      if (centralDesconectada ||
          item.conexion.toUpperCase() != 'CONECTADO') {

        estadoIncidencia = 'DESCONECTADO';

      }

      // ========================================================
      // PRIORIDAD 2: RETIRADO
      // ========================================================

      else if (item.estado.toUpperCase() == 'RETIRADO') {

        estadoIncidencia = 'RETIRADO';

      }

      // ========================================================
      // TODO CORRECTO
      // ========================================================

      else {

        estadoIncidencia = 'CORRECTO';
      }

      // ========================================================
      // SI HAY INCIDENCIA
      // ========================================================

      if (estadoIncidencia != 'CORRECTO') {

        final anterior =
        _incidenciasActivas[item.nombre];

        // Si ya existe con el mismo estado,
        // conservamos su hora original.
        if (anterior != null &&
            anterior.estado == estadoIncidencia) {

          continue;
        }

        // Si cambió de RETIRADO a DESCONECTADO
        // o viceversa, actualizamos la hora.
        _incidenciasActivas[item.nombre] =
            IncidenciaEpp(
              nombre: item.nombre,
              estado: estadoIncidencia,
              fechaHora: ahora,
            );

      }

      // ========================================================
      // SI YA ESTÁ CORRECTO
      // SE ELIMINA DEL HISTORIAL
      // ========================================================

      else {

        _incidenciasActivas.remove(item.nombre);
      }
    }
  }
  // ==========================================================
// OBTENER FECHA ACTUAL DEL CONTADOR
// ==========================================================

  String _obtenerDiaActual() {

    final ahora = DateTime.now();

    return '${ahora.year}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')}';
  }


// ==========================================================
// INICIALIZAR CONTADORES
// ==========================================================

  Future<void> _inicializarContadores() async {

    final prefs =
    await SharedPreferences.getInstance();

    final hoy =
    _obtenerDiaActual();

    final fechaGuardada =
    prefs.getString('safevision_fecha_contadores');


    // ========================================================
    // SI CAMBIÓ EL DÍA
    // ========================================================

    if (fechaGuardada != hoy) {

      _contadorIncidencias.clear();

      _contadorDesconexiones.clear();

      _desconexionSistema = 0;

      await prefs.setString(
        'safevision_fecha_contadores',
        hoy,
      );

      _fechaContadores = hoy;

      return;
    }


    // ========================================================
    // CARGAR INCIDENCIAS
    // ========================================================

    for (final nombre in [
      'Casco',
      'Chaleco',
      'Lentes',
      'Guante izquierdo',
      'Guante derecho',
      'Bota izquierda',
      'Bota derecha',
    ]) {

      _contadorIncidencias[nombre] =
          prefs.getInt(
            'incidencia_$nombre',
          ) ??
              0;

      _contadorDesconexiones[nombre] =
          prefs.getInt(
            'desconexion_$nombre',
          ) ??
              0;
    }


    // ========================================================
    // DESCONEXIÓN DEL SISTEMA
    // ========================================================

    _desconexionSistema =
        prefs.getInt(
          'desconexion_sistema',
        ) ??
            0;


    _fechaContadores =
        hoy;
  }


// ==========================================================
// GUARDAR CONTADORES
// ==========================================================

  Future<void> _guardarContadores() async {

    final prefs =
    await SharedPreferences.getInstance();


    await prefs.setString(
      'safevision_fecha_contadores',
      _obtenerDiaActual(),
    );


    for (final entry
    in _contadorIncidencias.entries) {

      await prefs.setInt(
        'incidencia_${entry.key}',
        entry.value,
      );
    }


    for (final entry
    in _contadorDesconexiones.entries) {

      await prefs.setInt(
        'desconexion_${entry.key}',
        entry.value,
      );
    }


    await prefs.setInt(
      'desconexion_sistema',
      _desconexionSistema,
    );
  }


// ==========================================================
// SUMAR INCIDENCIA
// ==========================================================

  void _sumarIncidencia(
      String equipo,
      ) {

    _contadorIncidencias[equipo] =
        (_contadorIncidencias[equipo] ?? 0) + 1;

    print(
      '🚨 INCIDENCIA +1 → '
          '$equipo = '
          '${_contadorIncidencias[equipo]}',
    );
  }


// ==========================================================
// SUMAR DESCONEXIÓN INDIVIDUAL
// ==========================================================

  void _sumarDesconexion(
      String equipo,
      ) {

    _contadorDesconexiones[equipo] =
        (_contadorDesconexiones[equipo] ?? 0) + 1;

    print(
      '🔴 DESCONEXIÓN +1 → '
          '$equipo = '
          '${_contadorDesconexiones[equipo]}',
    );
  }


// ==========================================================
// SUMAR DESCONEXIÓN DEL SISTEMA COMPLETO
// ==========================================================

  void _sumarDesconexionSistema() {

    _desconexionSistema++;

    print(
      '🚨 DESCONEXIÓN DEL SISTEMA +1 → '
          '$_desconexionSistema',
    );
  }


// ==========================================================
// PROCESAR CONTADORES
// ==========================================================

  Future<void> _procesarContadores(
      EstadoEpp estado,
      ) async {

    final equipos = <EppItem>[
      estado.casco,
      estado.chaleco,
      estado.lentes,
      estado.guanteIzquierdo,
      estado.guanteDerecho,
      estado.botaIzquierda,
      estado.botaDerecha,
    ];


    // ========================================================
    // CASCO / SISTEMA
    // ========================================================

    final bool sistemaConectado =
        estado.casco.conexion.toUpperCase() ==
            'CONECTADO';


    // ========================================================
    // PRIMERA LECTURA
    //
    // NO CUENTA NADA.
    // ========================================================

    if (_primeraLectura) {

      _primeraLectura = false;

      _sistemaConectadoAnterior =
          sistemaConectado;


      for (final equipo in equipos) {

        _estadosAnteriores[equipo.nombre] =
            equipo.estado.toUpperCase();

        _conexionesAnteriores[equipo.nombre] =
            equipo.conexion.toUpperCase();
      }


      return;
    }


    // ========================================================
    // DESCONEXIÓN DEL SISTEMA COMPLETO
    // ========================================================

    if (!sistemaConectado) {

      if (_sistemaConectadoAnterior == true) {

        _sumarDesconexionSistema();

        await _guardarContadores();
      }


      _sistemaConectadoAnterior =
      false;


      return;
    }


    // ========================================================
    // SISTEMA VOLVIÓ A CONECTARSE
    // ========================================================

    _sistemaConectadoAnterior =
    true;


    // ========================================================
    // PROCESAR CADA EQUIPO
    // ========================================================

    for (final equipo in equipos) {

      final nombre =
          equipo.nombre;

      final estadoActual =
      equipo.estado.toUpperCase();

      final conexionActual =
      equipo.conexion.toUpperCase();


      final estadoAnterior =
      _estadosAnteriores[nombre];

      final conexionAnterior =
      _conexionesAnteriores[nombre];


      // ======================================================
      // INCIDENCIA:
      //
      // SOLO CUANDO CAMBIA:
      //
      // NO RETIRADO → RETIRADO
      //
      // Si permanece RETIRADO:
      // NO SUMA.
      // ======================================================

      if (estadoActual == 'RETIRADO' &&
          estadoAnterior != 'RETIRADO') {

        _sumarIncidencia(nombre);
      }


      // ======================================================
      // DESCONEXIÓN:
      //
      // SOLO CUANDO CAMBIA:
      //
      // CONECTADO → DESCONECTADO
      //
      // Si permanece desconectado:
      // NO SUMA.
      // ======================================================

      if (conexionActual != 'CONECTADO' &&
          conexionAnterior == 'CONECTADO') {

        _sumarDesconexion(nombre);
      }


      // ======================================================
      // GUARDAR ESTADO ACTUAL
      // ======================================================

      _estadosAnteriores[nombre] =
          estadoActual;

      _conexionesAnteriores[nombre] =
          conexionActual;
    }


    // ========================================================
    // GUARDAR
    // ========================================================

    await _guardarContadores();
  }
  // ==========================================================
  // CONSULTAR API
  // ==========================================================
  Future<void> actualizarDatos() async {
    // --------------------------------------------------------
    // CANDADO DE SONDEO ASÍNCRONO
    // Evita ejecuciones simultáneas de actualizarDatos()
    // --------------------------------------------------------
    if (_consultaEnCurso) {
      return;
    }

    _consultaEnCurso = true;
    final int idConsulta = ++_idConsultaActual;

    try {
      // ========================================================
      // OBTENER ESTADO COMPLETO DE LA CENTRAL (CASCO)
      // ========================================================
      final jsonData = await Esp32Service.obtenerEstado();

      // Si una consulta posterior se completó mientras esta esperaba, descartamos
      if (idConsulta != _idConsultaActual) {
        return;
      }

      // ========================================================
      // MANEJO DE CAÍDA DE LA CENTRAL:
      // Solamente cuando la APP realmente pierde comunicación con
      // http://192.168.4.1/estado durante varios intentos consecutivos.
      // ========================================================
      if (jsonData == null) {
        _fallosConsecutivosCasco++;
        print('');
        print('========================================');
        print('⚠️ FALLO DE COMUNICACIÓN CON CASCO ($_fallosConsecutivosCasco/3)');
        print('========================================');

        // Si es un fallo transitorio (< 3 intentos) y ya teníamos datos válidos,
        // no destruimos el estado en pantalla ni disparamos falsas alarmas.
        if (_fallosConsecutivosCasco < 3 && datos != null) {
          if (mounted) {
            setState(() {
              horaActual = DateTime.now();
            });
          }
          return;
        }

        // Falla persistente (3 o más intentos consecutivos):
        // Recién entonces se considera que la central y el sistema perdieron conexión.
        if (!mounted) return;

        EppItem crearSecundarioVacio(String nombre) {
          return EppItem(
            nombre: nombre,
            estado: 'DESCONOCIDO',
            incidencias: _contadorIncidencias[nombre] ?? 0,
            desconexiones: _contadorDesconexiones[nombre] ?? 0,
            conexion: 'DESCONECTADO',
            tipo: 'SECUNDARIO',
          );
        }

        final EstadoEpp estadoDesconectado = EstadoEpp(
          fechaHora: DateTime.now(),
          estadoSistema: 'DESCONECTADO',
          central: 'CASCO',
          casco: EppItem(
            nombre: 'Casco',
            estado: 'DESCONOCIDO',
            incidencias: _contadorIncidencias['Casco'] ?? 0,
            desconexiones: _contadorDesconexiones['Casco'] ?? 0,
            conexion: 'DESCONECTADO',
            tipo: 'CENTRAL',
          ),
          chaleco: crearSecundarioVacio('Chaleco'),
          lentes: crearSecundarioVacio('Lentes'),
          guanteIzquierdo: crearSecundarioVacio('Guante izquierdo'),
          guanteDerecho: crearSecundarioVacio('Guante derecho'),
          botaIzquierda: crearSecundarioVacio('Bota izquierda'),
          botaDerecha: crearSecundarioVacio('Bota derecha'),
          totalIncidencias: _contadorIncidencias.values.fold(
            0,
            (total, cantidad) => total + cantidad,
          ),
          totalDesconexiones: _desconexionSistema +
              _contadorDesconexiones.values.fold(
                0,
                (total, cantidad) => total + cantidad,
              ),
        );

        await _procesarContadores(estadoDesconectado);

        setState(() {
          datos = estadoDesconectado;
          conectado = false;
          cargando = false;
          errorMensaje = 'Error conectando con el CASCO';
          horaActual = DateTime.now();
        });

        await _procesarAlertas(estadoDesconectado);
        _actualizarHistorialIncidencias(estadoDesconectado);
        return;
      }

      // Si el CASCO respondió correctamente (HTTP 200 con JSON válido):
      _fallosConsecutivosCasco = 0;

      // ========================================================
      // 1. CASCO (CENTRAL)
      // La conexión del casco depende EXCLUSIVAMENTE de la
      // comunicación real con la central, NO de su sensor físico.
      // Si recibimos JSON válido, el CASCO está CONECTADO.
      // ========================================================
      final Map<String, dynamic> datosCasco =
          Map<String, dynamic>.from(jsonData['casco'] ?? {});

      final String estadoCasco =
          datosCasco['estado']?.toString().trim().toUpperCase() ?? 'DESCONOCIDO';

      final int sensor = int.tryParse(
            datosCasco['sensor']?.toString() ?? '-1',
          ) ??
          -1;

      final EppItem casco = EppItem(
        nombre: 'Casco',
        estado: estadoCasco,
        incidencias: _contadorIncidencias['Casco'] ?? 0,
        desconexiones: _contadorDesconexiones['Casco'] ?? 0,
        conexion: 'CONECTADO',
        tipo: 'CENTRAL',
      );

      print('');
      print('========================================');
      print('📡 ESTADO GENERAL');
      print('========================================');
      print('CASCO: $estadoCasco');
      print('CONEXIÓN CASCO: CONECTADO');
      print('SENSOR: $sensor');
      print('SISTEMA: CONECTADO');
      print('========================================');

      // ========================================================
      // 2. CHALECO (SECUNDARIO) - TOTALMENTE INDEPENDIENTE
      // "RETIRADO" JAMÁS significa "DESCONECTADO".
      // Que el casco esté RETIRADO no modifica el chaleco.
      // ========================================================
      EppItem chaleco;
      final dynamic rawChaleco = jsonData['chaleco'];
      if (rawChaleco is Map) {
        final Map<String, dynamic> datosChaleco =
            Map<String, dynamic>.from(rawChaleco);

        final String estadoChalecoRaw =
            datosChaleco['estado']?.toString().trim().toUpperCase() ?? '';

        final String conexionChalecoRaw =
            datosChaleco['conexion']?.toString().trim().toUpperCase() ?? '';

        final bool chalecoEstaConectado = (datosChaleco['conectado'] == true ||
            conexionChalecoRaw == 'CONECTADO');

        if (chalecoEstaConectado) {
          _fallosConsecutivosChaleco = 0;
          chaleco = EppItem(
            nombre: 'Chaleco',
            estado: estadoChalecoRaw.isNotEmpty && estadoChalecoRaw != 'DESCONOCIDO'
                ? estadoChalecoRaw
                : (datos?.chaleco.estado != null && datos!.chaleco.estado != 'DESCONOCIDO'
                    ? datos!.chaleco.estado
                    : 'PUESTO'),
            incidencias: _contadorIncidencias['Chaleco'] ?? 0,
            desconexiones: _contadorDesconexiones['Chaleco'] ?? 0,
            conexion: 'CONECTADO',
            tipo: 'SECUNDARIO',
          );
        } else {
          // Si hubo un fallo puntual de comunicación (< 3 intentos) y ya teníamos datos válidos:
          _fallosConsecutivosChaleco++;
          if (_fallosConsecutivosChaleco < 3 &&
              datos != null &&
              datos!.chaleco.conexion == 'CONECTADO') {
            chaleco = EppItem(
              nombre: 'Chaleco',
              estado: datos!.chaleco.estado,
              incidencias: _contadorIncidencias['Chaleco'] ?? 0,
              desconexiones: _contadorDesconexiones['Chaleco'] ?? 0,
              conexion: 'CONECTADO',
              tipo: 'SECUNDARIO',
            );
          } else {
            chaleco = EppItem(
              nombre: 'Chaleco',
              estado: 'DESCONOCIDO',
              incidencias: _contadorIncidencias['Chaleco'] ?? 0,
              desconexiones: _contadorDesconexiones['Chaleco'] ?? 0,
              conexion: 'DESCONECTADO',
              tipo: 'SECUNDARIO',
            );
          }
        }
      } else {
        if (datos != null &&
            datos!.chaleco.conexion == 'CONECTADO' &&
            _fallosConsecutivosChaleco < 3) {
          _fallosConsecutivosChaleco++;
          chaleco = EppItem(
            nombre: 'Chaleco',
            estado: datos!.chaleco.estado,
            incidencias: _contadorIncidencias['Chaleco'] ?? 0,
            desconexiones: _contadorDesconexiones['Chaleco'] ?? 0,
            conexion: 'CONECTADO',
            tipo: 'SECUNDARIO',
          );
        } else {
          chaleco = EppItem(
            nombre: 'Chaleco',
            estado: 'DESCONOCIDO',
            incidencias: _contadorIncidencias['Chaleco'] ?? 0,
            desconexiones: _contadorDesconexiones['Chaleco'] ?? 0,
            conexion: 'DESCONECTADO',
            tipo: 'SECUNDARIO',
          );
        }
      }

      print('🦺 CHALECO: ESTADO=${chaleco.estado} | CONEXIÓN=${chaleco.conexion}');

      // ========================================================
      // 3. LENTES (SECUNDARIO) - TOTALMENTE INDEPENDIENTE
      // ========================================================
      EppItem lentes;
      final dynamic rawLentes = jsonData['lentes'];
      if (rawLentes is Map) {
        final Map<String, dynamic> datosLentes =
            Map<String, dynamic>.from(rawLentes);

        final String estadoLentesRaw =
            datosLentes['estado']?.toString().trim().toUpperCase() ?? '';

        final String conexionLentesRaw =
            datosLentes['conexion']?.toString().trim().toUpperCase() ?? '';

        final bool lentesEstaConectado = (datosLentes['conectado'] == true ||
            conexionLentesRaw == 'CONECTADO');

        if (lentesEstaConectado) {
          _fallosConsecutivosLentes = 0;
          lentes = EppItem(
            nombre: 'Lentes',
            estado: estadoLentesRaw.isNotEmpty && estadoLentesRaw != 'DESCONOCIDO'
                ? estadoLentesRaw
                : (datos?.lentes.estado != null && datos!.lentes.estado != 'DESCONOCIDO'
                    ? datos!.lentes.estado
                    : 'PUESTO'),
            incidencias: _contadorIncidencias['Lentes'] ?? 0,
            desconexiones: _contadorDesconexiones['Lentes'] ?? 0,
            conexion: 'CONECTADO',
            tipo: 'SECUNDARIO',
          );
        } else {
          _fallosConsecutivosLentes++;
          if (_fallosConsecutivosLentes < 3 &&
              datos != null &&
              datos!.lentes.conexion == 'CONECTADO') {
            lentes = EppItem(
              nombre: 'Lentes',
              estado: datos!.lentes.estado,
              incidencias: _contadorIncidencias['Lentes'] ?? 0,
              desconexiones: _contadorDesconexiones['Lentes'] ?? 0,
              conexion: 'CONECTADO',
              tipo: 'SECUNDARIO',
            );
          } else {
            lentes = EppItem(
              nombre: 'Lentes',
              estado: 'DESCONOCIDO',
              incidencias: _contadorIncidencias['Lentes'] ?? 0,
              desconexiones: _contadorDesconexiones['Lentes'] ?? 0,
              conexion: 'DESCONECTADO',
              tipo: 'SECUNDARIO',
            );
          }
        }
      } else {
        if (datos != null &&
            datos!.lentes.conexion == 'CONECTADO' &&
            _fallosConsecutivosLentes < 3) {
          _fallosConsecutivosLentes++;
          lentes = EppItem(
            nombre: 'Lentes',
            estado: datos!.lentes.estado,
            incidencias: _contadorIncidencias['Lentes'] ?? 0,
            desconexiones: _contadorDesconexiones['Lentes'] ?? 0,
            conexion: 'CONECTADO',
            tipo: 'SECUNDARIO',
          );
        } else {
          lentes = EppItem(
            nombre: 'Lentes',
            estado: 'DESCONOCIDO',
            incidencias: _contadorIncidencias['Lentes'] ?? 0,
            desconexiones: _contadorDesconexiones['Lentes'] ?? 0,
            conexion: 'DESCONECTADO',
            tipo: 'SECUNDARIO',
          );
        }
      }

      print('👓 LENTES: ESTADO=${lentes.estado} | CONEXIÓN=${lentes.conexion}');

      // ========================================================
      // 4. RESTO DE EPP (SECUNDARIOS PENDIENTES DE HARDWARE)
      // ========================================================
      EppItem crearSecundario(String nombre) {
        return EppItem(
          nombre: nombre,
          estado: 'DESCONOCIDO',
          incidencias: _contadorIncidencias[nombre] ?? 0,
          desconexiones: _contadorDesconexiones[nombre] ?? 0,
          conexion: 'DESCONECTADO',
          tipo: 'SECUNDARIO',
        );
      }

      final EppItem guanteIzquierdo = crearSecundario('Guante izquierdo');
      final EppItem guanteDerecho = crearSecundario('Guante derecho');
      final EppItem botaIzquierda = crearSecundario('Bota izquierda');
      final EppItem botaDerecha = crearSecundario('Bota derecha');

      // ========================================================
      // ESTADO GENERAL DEL SISTEMA
      // ========================================================
      final EstadoEpp nuevoEstado = EstadoEpp(
        fechaHora: DateTime.now(),
        estadoSistema: 'CONECTADO',
        central: 'CASCO',
        casco: casco,
        chaleco: chaleco,
        lentes: lentes,
        guanteIzquierdo: guanteIzquierdo,
        guanteDerecho: guanteDerecho,
        botaIzquierda: botaIzquierda,
        botaDerecha: botaDerecha,
        totalIncidencias: _contadorIncidencias.values.fold(
          0,
          (total, cantidad) => total + cantidad,
        ),
        totalDesconexiones: _desconexionSistema +
            _contadorDesconexiones.values.fold(
              0,
              (total, cantidad) => total + cantidad,
            ),
      );

      // ========================================================
      // PROCESAR CONTADORES DE EVENTOS
      // ========================================================
      await _procesarContadores(nuevoEstado);

      // ========================================================
      // ACTUALIZAR INTERFAZ
      // ========================================================
      if (!mounted) {
        return;
      }

      setState(() {
        datos = nuevoEstado;
        conectado = true;
        cargando = false;
        errorMensaje = '';
        horaActual = DateTime.now();
      });

      // ========================================================
      // PROCESAR ALERTAS Y HISTORIAL
      // ========================================================
      await _procesarAlertas(nuevoEstado);
      _actualizarHistorialIncidencias(nuevoEstado);

      print('✅ DATOS MOSTRADOS EN LA APP');
    } catch (e) {
      print('❌ ERROR APP → ESP32: $e');

      _fallosConsecutivosCasco++;

      if (_fallosConsecutivosCasco < 3 && datos != null) {
        if (mounted) {
          setState(() {
            horaActual = DateTime.now();
          });
        }
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        conectado = false;
        cargando = false;
        errorMensaje = 'Error conectando con el ESP32';
      });
    } finally {
      _consultaEnCurso = false;
    }
  }

  // ==========================================================
  // FECHA
  // ==========================================================

  String obtenerFecha(DateTime fecha) {

    String dos(int numero) =>
        numero.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}:${dos(fecha.second)}';
  }

  // ==========================================================
  // INTERFAZ
  // ==========================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        elevation: 0,

        backgroundColor:
        const Color(0xFF0B172A),

        foregroundColor: Colors.white,

        title: Row(
          children: [

            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                const Color(0xFF0F766E),
                borderRadius:
                BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 12),

            const Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [

                Text(
                  'SafeVisionEPP',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 19,
                  ),
                ),

                Text(
                  'Monitoreo de EPP',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                    Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [

          IconButton(
            tooltip: 'Actualizar',
            onPressed: actualizarDatos,
            icon: const Icon(
              Icons.refresh,
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: RefreshIndicator(

        onRefresh: actualizarDatos,

        child: datos == null
            ? _pantallaInicial()
            : _dashboard(),
      ),
    );
  }

  // ==========================================================
  // PANTALLA DE CARGA / ERROR
  // ==========================================================

  Widget _pantallaInicial() {

    return ListView(

      physics:
      const AlwaysScrollableScrollPhysics(),

      children: [

        const SizedBox(height: 130),

        Center(
          child: Column(
            children: [

              Container(
                width: 80,
                height: 80,
                decoration:
                BoxDecoration(
                  color:
                  const Color(0xFFE0F2F1),
                  borderRadius:
                  BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 42,
                  color:
                  Color(0xFF0F766E),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Conectando con SafeVisionEPP...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              if (cargando)
                const CircularProgressIndicator(),

              if (errorMensaje.isNotEmpty)
                Padding(
                  padding:
                  const EdgeInsets.all(20),
                  child: Text(
                    errorMensaje,
                    textAlign:
                    TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // DASHBOARD
  // ==========================================================

  Widget _dashboard() {

    final epp = datos!;

    return ListView(

      physics:
      const AlwaysScrollableScrollPhysics(),

      padding:
      const EdgeInsets.all(16),

      children: [

        // ------------------------------------------------------
        // ESTADO GENERAL
        // ------------------------------------------------------

        Container(

          padding:
          const EdgeInsets.all(18),

          decoration:
          BoxDecoration(

            color: Colors.white,

            borderRadius:
            BorderRadius.circular(18),

            boxShadow: [

              BoxShadow(
                color:
                Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset:
                const Offset(0, 4),
              ),
            ],
          ),

          child: Row(

            children: [

              Container(
                width: 52,
                height: 52,
                decoration:
                BoxDecoration(
                  color: conectado
                      ? const Color(
                      0xFFDCFCE7)
                      : const Color(
                      0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  conectado
                      ? Icons.wifi
                      : Icons.wifi_off,
                  color: conectado
                      ? const Color(
                      0xFF16A34A)
                      : Colors.red,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    const Text(
                      'Estado del sistema',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                        Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [

                        Container(
                          width: 9,
                          height: 9,
                          decoration:
                          BoxDecoration(
                            color: conectado
                                ? Colors.green
                                : Colors.red,
                            shape:
                            BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 7),

                        Text(
                          conectado
                              ? epp.estadoSistema
                              : 'DESCONECTADO',
                          style:
                          TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight.bold,
                            color: conectado
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [

                  const Text(
                    'Central',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                      Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    epp.central,
                    style: const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ------------------------------------------------------
        // FECHA Y HORA
        // ------------------------------------------------------

        Container(

          padding:
          const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),

          decoration:
          BoxDecoration(

            color:
            const Color(0xFF0B172A),

            borderRadius:
            BorderRadius.circular(14),
          ),

          child: Row(

            children: [

              const Icon(
                Icons.access_time,
                color: Colors.white70,
                size: 20,
              ),

              const SizedBox(width: 10),

              const Text(
                'Última actualización',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),

              const Spacer(),

              Text(
                obtenerFecha(horaActual),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ------------------------------------------------------
        // TÍTULO
        // ------------------------------------------------------

        const Text(
          'Equipos de protección',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
            FontWeight.bold,
            color:
            Color(0xFF0B172A),
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          'Estado actual de cada implemento',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 14),

        // ------------------------------------------------------
        // CASCO
        // ------------------------------------------------------

        _tarjetaEpp(
          epp.casco,
          Icons.sports_motorsports,
        ),

        _tarjetaEpp(
          epp.chaleco,
          Icons.security,
        ),

        _tarjetaEpp(
          epp.lentes,
          Icons.visibility,
        ),

        _tarjetaEpp(
          epp.guanteIzquierdo,
          Icons.back_hand,
        ),

        _tarjetaEpp(
          epp.guanteDerecho,
          Icons.back_hand,
        ),

        _tarjetaEpp(
          epp.botaIzquierda,
          Icons.hiking,
        ),

        _tarjetaEpp(
          epp.botaDerecha,
          Icons.hiking,
        ),

        const SizedBox(height: 8),

// ------------------------------------------------------
// INCIDENCIAS ACTIVAS
// ------------------------------------------------------

        _tablaIncidencias(),

        const SizedBox(height: 20),

// ------------------------------------------------------
// RESUMEN
// ------------------------------------------------------

        const Text(
          'Resumen',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
            FontWeight.bold,
            color:
            Color(0xFF0B172A),
          ),
        ),

        const SizedBox(height: 14),

        Row(

          children: [

            Expanded(
              child: _tarjetaResumen(
                titulo: 'Incidencias',
                valor:
                epp.totalIncidencias
                    .toString(),
                icono:
                Icons.warning_amber_rounded,
                color:
                const Color(0xFFEA580C),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _tarjetaResumen(
                titulo: 'Desconexiones',
                valor:
                epp.totalDesconexiones
                    .toString(),
                icono:
                Icons.link_off,
                color:
                const Color(0xFFDC2626),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ------------------------------------------------------
        // PIE
        // ------------------------------------------------------

        Center(
          child: Text(
            'SafeVisionEPP • Monitoreo en tiempo real',
            style: TextStyle(
              color:
              Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
// ==========================================================
// TABLA DE INCIDENCIAS ACTIVAS
// ==========================================================

  Widget _tablaIncidencias() {

    final incidencias =
    _incidenciasActivas.values.toList();

    // Ordenar por fecha más reciente
    incidencias.sort(
          (a, b) => b.fechaHora.compareTo(a.fechaHora),
    );

    return Container(

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(17),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          // ====================================================
          // TÍTULO
          // ====================================================

          Row(
            children: [

              Icon(
                incidencias.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,

                color: incidencias.isEmpty
                    ? const Color(0xFF16A34A)
                    : Colors.red,

                size: 22,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Estado de incidencias',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ====================================================
          // TODO CORRECTO
          // ====================================================

          if (incidencias.isEmpty)

            Container(

              width: double.infinity,

              padding:
              const EdgeInsets.all(14),

              decoration: BoxDecoration(

                color:
                const Color(0xFFDCFCE7),

                borderRadius:
                BorderRadius.circular(10),
              ),

              child: const Row(

                children: [

                  Icon(
                    Icons.verified,
                    color:
                    Color(0xFF16A34A),
                    size: 20,
                  ),

                  SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      'Todos los equipos están puestos y conectados.',
                      style: TextStyle(
                        color:
                        Color(0xFF166534),
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )

          // ====================================================
          // EXISTEN INCIDENCIAS
          // ====================================================

          else

            Container(

              width: double.infinity,

              decoration: BoxDecoration(

                border:
                Border.all(
                  color:
                  const Color(0xFFE5E7EB),
                ),

                borderRadius:
                BorderRadius.circular(10),
              ),

              child: Column(
                children: [

                  // ENCABEZADO

                  Container(

                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),

                    decoration: const BoxDecoration(

                      color:
                      Color(0xFFF8FAFC),

                      borderRadius:
                      BorderRadius.vertical(
                        top:
                        Radius.circular(10),
                      ),
                    ),

                    child: const Row(

                      children: [

                        Expanded(
                          flex: 3,
                          child: Text(
                            'Equipo',
                            style:
                            TextStyle(
                              fontSize: 10,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),

                        Expanded(
                          flex: 2,
                          child: Text(
                            'Estado',
                            style:
                            TextStyle(
                              fontSize: 10,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),

                        Expanded(
                          flex: 3,
                          child: Text(
                            'Fecha / hora',
                            textAlign:
                            TextAlign.right,
                            style:
                            TextStyle(
                              fontSize: 10,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // FILAS

                  ...incidencias.map(
                        (incidencia) =>
                        _filaIncidencia(
                          incidencia,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  // ==========================================================
// FILA DE INCIDENCIA
// ==========================================================

  Widget _filaIncidencia(
      IncidenciaEpp incidencia,
      ) {

    final bool desconectado =
        incidencia.estado == 'DESCONECTADO';

    final Color color =
    desconectado
        ? Colors.red
        : const Color(0xFFEA580C);

    String dos(int numero) =>
        numero.toString().padLeft(2, '0');

    final fecha =
        '${dos(incidencia.fechaHora.day)}/'
        '${dos(incidencia.fechaHora.month)}/'
        '${incidencia.fechaHora.year}';

    final hora =
        '${dos(incidencia.fechaHora.hour)}:'
        '${dos(incidencia.fechaHora.minute)}:'
        '${dos(incidencia.fechaHora.second)}';

    return Container(

      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 11,
      ),

      decoration: const BoxDecoration(

        border: Border(
          top: BorderSide(
            color:
            Color(0xFFE5E7EB),
          ),
        ),
      ),

      child: Row(

        children: [

          // ==================================================
          // EQUIPO
          // ==================================================

          Expanded(
            flex: 3,

            child: Text(
              incidencia.nombre,
              style: const TextStyle(
                fontSize: 11,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          // ==================================================
          // ESTADO
          // ==================================================

          Expanded(
            flex: 2,

            child: Align(
              alignment:
              Alignment.centerLeft,

              child: Container(

                padding:
                const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),

                decoration:
                BoxDecoration(
                  color:
                  color.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),

                child: Text(
                  incidencia.estado,

                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // ==================================================
          // FECHA Y HORA
          // ==================================================

          Expanded(
            flex: 3,

            child: Column(

              crossAxisAlignment:
              CrossAxisAlignment.end,

              children: [

                Text(
                  fecha,
                  style:
                  const TextStyle(
                    fontSize: 9,
                    color:
                    Colors.black87,
                  ),
                ),

                Text(
                  hora,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ==========================================================
  // TARJETA EPP
  // ==========================================================

  Widget _tarjetaEpp(
      EppItem item,
      IconData icono,
      ) {
    final bool estaConectado =
        item.conexion.trim().toUpperCase() == 'CONECTADO';

    final bool estaPuesto =
        item.estado.trim().toUpperCase() == 'PUESTO';

    final bool correcto =
        estaConectado && estaPuesto;

    Color colorEstado;

    if (!estaConectado) {
      colorEstado = Colors.red;
    } else if (!estaPuesto) {
      colorEstado = const Color(0xFFEA580C);
    } else {
      colorEstado = const Color(0xFF16A34A);
    }

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: correcto
              ? const Color(0xFFE5E7EB)
              : colorEstado.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ====================================================
          // ICONO
          // ====================================================

          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icono,
              color: colorEstado,
              size: 27,
            ),
          ),

          const SizedBox(width: 13),

          // ====================================================
          // INFORMACIÓN
          // ====================================================

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  item.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // AQUÍ ESTABA EL OVERFLOW
                // Ahora usamos Wrap para que se adapte
                // al ancho del celular.

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _miniEstado(
                      'Estado',
                      item.estado,
                    ),

                    _miniEstado(
                      'Conexión',
                      item.conexion,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ====================================================
          // ESTADO FINAL + INCIDENCIAS
          // ====================================================

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              Container(
                constraints: const BoxConstraints(
                  minWidth: 78,
                  maxWidth: 105,
                ),

                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Text(
                  !estaConectado
                      ? 'DESCONECTADO'
                      : !estaPuesto
                      ? 'RETIRADO'
                      : 'CORRECTO',

                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    color: colorEstado,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Inc. ${item.incidencias}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MINI ESTADO
  // ==========================================================

  Widget _miniEstado(
      String titulo,
      String valor,
      ) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 125,
      ),

      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),

      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),

      child: Text(
        '$titulo: $valor',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.black54,
        ),
      ),
    );
  }

  // ==========================================================
  // TARJETA RESUMEN
  // ==========================================================

  Widget _tarjetaResumen({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {

    return Container(

      padding:
      const EdgeInsets.all(18),

      decoration:
      BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(18),

        boxShadow: [

          BoxShadow(
            color:
            Colors.black.withOpacity(
              0.04,
            ),
            blurRadius: 8,
            offset:
            const Offset(0, 3),
          ),
        ],
      ),

      child: Column(

        children: [

          Container(
            width: 44,
            height: 44,

            decoration:
            BoxDecoration(
              color:
              color.withOpacity(
                0.10,
              ),
              shape: BoxShape.circle,
            ),

            child: Icon(
              icono,
              color: color,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            titulo,
            textAlign:
            TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            valor,
            style: TextStyle(
              fontSize: 25,
              fontWeight:
              FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}