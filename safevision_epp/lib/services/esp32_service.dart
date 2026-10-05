import 'dart:convert';
import 'package:http/http.dart' as http;

class Esp32Service {

  // ==========================================================
  // CASCO - CENTRAL
  // ==========================================================

  static const String ipCasco = '192.168.4.1';

  static const Duration timeout =
  Duration(seconds: 5);


  // ==========================================================
  // OBTENER ESTADO DEL CASCO Y DE TODOS LOS EPP
  // ==========================================================
  //
  // IMPORTANTE:
  //
  // Flutter solamente consulta al CASCO.
  //
  // El CASCO ya consulta al CHALECO y devuelve:
  //
  // {
  //   "casco": {...},
  //   "chaleco": {...},
  //   "sistema": {...}
  // }
  //
  // Por eso NO debemos meter toda la respuesta
  // dentro de "casco".
  //
  // Debemos conservar cada elemento en su lugar.
  // ==========================================================

  static Future<Map<String, dynamic>?> obtenerEstadoCasco() async {

    try {

      final response = await http
          .get(
        Uri.parse(
          'http://$ipCasco/estado',
        ),
      )
          .timeout(timeout);


      print('');
      print('========================================');
      print('🪖 CASCO - CENTRAL');
      print('========================================');
      print('HTTP: ${response.statusCode}');
      print('RESPUESTA: ${response.body}');
      print('========================================');


      // ========================================================
      // VALIDAR HTTP
      // ========================================================

      if (response.statusCode != 200) {

        print(
          '❌ CASCO RESPONDIÓ HTTP '
              '${response.statusCode}',
        );

        return null;
      }


      // ========================================================
      // DECODIFICAR JSON
      // ========================================================

      final dynamic data =
      jsonDecode(response.body);


      if (data is! Map) {

        print(
          '❌ RESPUESTA DEL CASCO NO ES JSON VÁLIDO',
        );

        return null;
      }


      final Map<String, dynamic> respuesta =
      Map<String, dynamic>.from(data);


      // ========================================================
      // CASCO
      // ========================================================
      //
      // El ESP32 puede devolver:
      //
      // "casco": {...}
      //
      // o, dependiendo de la versión:
      //
      // directamente:
      //
      // "estado": "PUESTO"
      //
      // Mantenemos compatibilidad con ambos formatos.
      // ========================================================

      Map<String, dynamic> datosCasco;


      if (respuesta['casco'] is Map) {

        datosCasco =
        Map<String, dynamic>.from(
          respuesta['casco'],
        );

      } else {

        datosCasco =
        Map<String, dynamic>.from(
          respuesta,
        );
      }


      // ========================================================
      // FORZAR CONEXIÓN DEL CASCO
      // ========================================================

      datosCasco['conexion'] =
      'CONECTADO';

      datosCasco['tipo'] =
      'CENTRAL';


      // ========================================================
      // CONSTRUIR RESPUESTA COMPLETA
      // ========================================================
      //
      // AQUÍ ESTÁ LA CORRECCIÓN PRINCIPAL.
      //
      // Conservamos:
      //
      // respuesta['chaleco']
      //
      // respuesta['lentes']
      //
      // etc.
      //
      // para que actualizarDatos() pueda leerlos.
      // ========================================================

      final Map<String, dynamic> resultado = {

        'casco':
        datosCasco,

      };


      // ========================================================
      // CHALECO
      // ========================================================

      if (respuesta['chaleco'] is Map) {

        final Map<String, dynamic> chaleco =
        Map<String, dynamic>.from(
          respuesta['chaleco'],
        );

        final String estadoChaleco =
            chaleco['estado']?.toString().trim().toUpperCase() ?? 'DESCONOCIDO';

        final String conexionChalecoRaw =
            chaleco['conexion']?.toString().trim().toUpperCase() ?? '';

        final bool conectadoChaleco =
            chaleco['conectado'] == true ||
            conexionChalecoRaw == 'CONECTADO';

        chaleco['conexion'] =
            conectadoChaleco ? 'CONECTADO' : 'DESCONECTADO';

        chaleco['estado'] = estadoChaleco;

        chaleco['tipo'] = 'SECUNDARIO';

        resultado['chaleco'] = chaleco;

      } else {

        resultado['chaleco'] = null;
      }


      // ========================================================
      // LENTES
      // ========================================================

      if (respuesta['lentes'] is Map) {

        final Map<String, dynamic> lentes =
        Map<String, dynamic>.from(
          respuesta['lentes'],
        );

        final String estadoLentes =
            lentes['estado']?.toString().trim().toUpperCase() ?? 'DESCONOCIDO';

        final String conexionLentesRaw =
            lentes['conexion']?.toString().trim().toUpperCase() ?? '';

        final bool conectadoLentes =
            lentes['conectado'] == true ||
            conexionLentesRaw == 'CONECTADO';

        lentes['conexion'] =
            conectadoLentes ? 'CONECTADO' : 'DESCONECTADO';

        lentes['estado'] = estadoLentes;

        lentes['tipo'] = 'SECUNDARIO';

        resultado['lentes'] = lentes;

      } else {

        resultado['lentes'] = null;
      }


      // ========================================================
      // GUANTE IZQUIERDO
      // ========================================================

      if (respuesta['guanteIzquierdo'] is Map) {

        resultado['guanteIzquierdo'] =
        Map<String, dynamic>.from(
          respuesta['guanteIzquierdo'],
        );

      } else {

        resultado['guanteIzquierdo'] = {

          'estado':
          'DESCONOCIDO',

          'conexion':
          'DESCONECTADO',

          'tipo':
          'SECUNDARIO',
        };
      }


      // ========================================================
      // GUANTE DERECHO
      // ========================================================

      if (respuesta['guanteDerecho'] is Map) {

        resultado['guanteDerecho'] =
        Map<String, dynamic>.from(
          respuesta['guanteDerecho'],
        );

      } else {

        resultado['guanteDerecho'] = {

          'estado':
          'DESCONOCIDO',

          'conexion':
          'DESCONECTADO',

          'tipo':
          'SECUNDARIO',
        };
      }


      // ========================================================
      // BOTA IZQUIERDA
      // ========================================================

      if (respuesta['botaIzquierda'] is Map) {

        resultado['botaIzquierda'] =
        Map<String, dynamic>.from(
          respuesta['botaIzquierda'],
        );

      } else {

        resultado['botaIzquierda'] = {

          'estado':
          'DESCONOCIDO',

          'conexion':
          'DESCONECTADO',

          'tipo':
          'SECUNDARIO',
        };
      }


      // ========================================================
      // BOTA DERECHA
      // ========================================================

      if (respuesta['botaDerecha'] is Map) {

        resultado['botaDerecha'] =
        Map<String, dynamic>.from(
          respuesta['botaDerecha'],
        );

      } else {

        resultado['botaDerecha'] = {

          'estado':
          'DESCONOCIDO',

          'conexion':
          'DESCONECTADO',

          'tipo':
          'SECUNDARIO',
        };
      }


      // ========================================================
      // SISTEMA
      // ========================================================

      if (respuesta['sistema'] is Map) {

        resultado['sistema'] =
        Map<String, dynamic>.from(
          respuesta['sistema'],
        );

      } else {

        resultado['sistema'] = {

          'estado':
          'CONECTADO',

          'central':
          'CASCO',
        };
      }


      // ========================================================
      // FECHA Y HORA
      // ========================================================

      resultado['fechaHora'] =
          DateTime.now().toIso8601String();


      // ========================================================
      // MOSTRAR RESULTADO
      // ========================================================

      print('');
      print('========================================');
      print('📡 RESPUESTA PROCESADA PARA FLUTTER');
      print('========================================');

      print(
        'CASCO: '
            '${resultado['casco']}',
      );

      print(
        'CHALECO: '
            '${resultado['chaleco']}',
      );

      print(
        'SISTEMA: '
            '${resultado['sistema']}',
      );

      print('========================================');


      return resultado;

    } catch (e) {

      print('');
      print('========================================');
      print('❌ CASCO DESCONECTADO');
      print('========================================');
      print('ERROR: $e');
      print('========================================');

      return null;
    }
  }


  // ==========================================================
  // OBTENER ESTADO COMPLETO
  // ==========================================================

  static Future<Map<String, dynamic>?> obtenerEstado() async {
    return await obtenerEstadoCasco();
  }


  // ==========================================================
  // PING CASCO
  // ==========================================================

  static Future<bool> probarConexionCasco() async {

    try {

      final response = await http
          .get(
        Uri.parse(
          'http://$ipCasco/ping',
        ),
      )
          .timeout(timeout);


      print(
        'PING CASCO: HTTP '
            '${response.statusCode}',
      );


      return response.statusCode == 200;

    } catch (e) {

      print(
        '❌ PING CASCO FALLÓ: $e',
      );

      return false;
    }
  }
}