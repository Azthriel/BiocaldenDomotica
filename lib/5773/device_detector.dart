import 'dart:convert';
import 'package:biocalden_smart_life/stored_data.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:biocalden_smart_life/5773/master_detector.dart';
import 'package:biocalden_smart_life/master.dart';

class DetectorPage extends StatefulWidget {
  const DetectorPage({super.key});
  @override
  DetectorPageState createState() => DetectorPageState();
}

class DetectorPageState extends State<DetectorPage> {
  late String nickname;
  bool werror = false;
  bool alert = false;
  String _textToShow = 'AIRE PURO';
  bool online = true;

  @override
  void initState() {
    super.initState();

    nickname = nicknamesMap[deviceName] ?? deviceName;
    _subscribeToWorkCharacteristic();
    subscribeToWifiStatus();
    updateWifiValues(toolsValues);
  }

  void updateWifiValues(List<int> data) {
    var fun = utf8.decode(data); //Wifi status | wifi ssid | ble status(users)
    fun = fun.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    printLog(fun);
    var parts = fun.split(':');
    if (parts[0] == 'WCS_CONNECTED') {
      nameOfWifi = parts[1];
      isWifiConnected = true;
      printLog('sis $isWifiConnected');
      setState(() {
        textState = 'CONECTADO';
        statusColor = Colors.green;
        wifiIcon = Icons.wifi;
        errorMessage = '';
        errorSintax = '';
        werror = false;
      });
    } else if (parts[0] == 'WCS_DISCONNECTED') {
      isWifiConnected = false;
      printLog('non $isWifiConnected');

      setState(() {
        textState = 'DESCONECTADO';
        statusColor = Colors.red;
        wifiIcon = Icons.wifi_off;
      });

      if (parts[0] == 'WCS_DISCONNECTED' && atemp == true) {
        //If comes from subscription, parts[1] = reason of error.
        setState(() {
          wifiIcon = Icons.warning_amber_rounded;
        });

        werror = true;

        if (parts[1] == '202' || parts[1] == '15') {
          errorMessage = 'Contraseña incorrecta';
        } else if (parts[1] == '201') {
          errorMessage = 'La red especificada no existe';
        } else if (parts[1] == '1') {
          errorMessage = 'Error desconocido';
        } else {
          errorMessage = parts[1];
        }

        errorSintax = getWifiErrorSintax(int.parse(parts[1]));
      }
    }

    setState(() {});
  }

  void subscribeToWifiStatus() async {
    printLog('Se subscribio a wifi');
    await myDevice.toolsUuid.setNotifyValue(true);

    final wifiSub =
        myDevice.toolsUuid.onValueReceived.listen((List<int> status) {
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
  }

  void _subscribeToWorkCharacteristic() async {
    await myDevice.workUuid.setNotifyValue(true);
    printLog('Me suscribí a work');
    final workSub =
        myDevice.workUuid.onValueReceived.listen((List<int> status) {
      printLog('Cositas: $status');
      setState(() {
        alert = status[4] == 1;
        ppmCO = status[5] + (status[6] << 8);
        ppmCH4 = status[7] + (status[8] << 8);
        picoMaxppmCO = status[9] + (status[10] << 8);
        picoMaxppmCH4 = status[11] + (status[12] << 8);
        promedioppmCO = status[17] + (status[18] << 8);
        promedioppmCH4 = status[19] + (status[20] << 8);
        daysToExpire = status[21] + (status[22] << 8);
        printLog('Parte baja CO: ${status[9]} // Parte alta CO: ${status[10]}');
        printLog('PPMCO: $ppmCO');
        printLog(
            'Parte baja CH4: ${status[11]} // Parte alta CH4: ${status[12]}');
        printLog('PPMCH4: $ppmCH4');
        printLog('Alerta: $alert');
        _textToShow = alert ? 'PELIGRO' : 'AIRE PURO';
      });
    });

    myDevice.device.cancelWhenDisconnected(workSub);
  }

  Future<void> _showEditNicknameDialog(BuildContext context) async {
    TextEditingController nicknameController =
        TextEditingController(text: nickname);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 230, 254, 255),
          title: const Text(
            'Editar identificación del dispositivo',
            style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
          ),
          content: TextField(
            style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
            cursorColor: const Color.fromARGB(255, 255, 255, 255),
            controller: nicknameController,
            decoration: const InputDecoration(
              hintText: "Introduce tu nueva identificación del dispositivo",
              hintStyle: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: const ButtonStyle(
                foregroundColor: MaterialStatePropertyAll(
                  Color.fromARGB(255, 29, 163, 169),
                ),
              ),
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Cierra el AlertDialog
              },
            ),
            TextButton(
              style: const ButtonStyle(
                foregroundColor: MaterialStatePropertyAll(
                  Color.fromARGB(255, 29, 163, 169),
                ),
              ),
              child: const Text('Guardar'),
              onPressed: () {
                setState(() {
                  String newNickname = nicknameController.text;
                  nickname = newNickname;
                  nicknamesMap[deviceName] = newNickname; // Actualizar el mapa
                  saveNicknamesMap(nicknamesMap);
                  printLog('$nicknamesMap');
                });
                Navigator.of(dialogContext).pop(); // Cierra el AlertDialog
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color.fromARGB(255, 230, 254, 255),
              content: Row(
                children: [
                  const CircularProgressIndicator(
                      color: Color.fromARGB(255, 29, 163, 169)),
                  Container(
                      margin: const EdgeInsets.only(left: 15),
                      child: const Text(
                        "Desconectando...",
                        style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                      )),
                ],
              ),
            );
          },
        );
        Future.delayed(const Duration(seconds: 2), () async {
          printLog('aca estoy');
          await myDevice.device.disconnect();
          navigatorKey.currentState?.pop();
          navigatorKey.currentState?.pushReplacementNamed('/scan');
        });

        return; // Retorna según la lógica de tu app
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 1, 18, 28),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color.fromARGB(255, 29, 163, 169),
            title: GestureDetector(
              onTap: () async {
                await _showEditNicknameDialog(context);
                setupToken();
              },
              child: Row(
                  children: [
                    Text(nickname),
                    const SizedBox(
                      width: 3,
                    ),
                    const Icon(
                      Icons.edit,
                      size: 20,
                    )
                  ],
                ),
            ),
            actions: <Widget>[
              IconButton(
                icon: Icon(
                  wifiIcon,
                  size: 24.0,
                  semanticLabel: 'Icono de wifi',
                ),
                onPressed: () {
                  showDialog(
                    barrierDismissible: true,
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor:
                            const Color.fromARGB(255, 230, 254, 255),
                        title: Row(children: [
                          const Text.rich(TextSpan(
                              text: 'Estado de conexión: ',
                              style: TextStyle(
                                color: Color.fromARGB(255, 0, 0, 0),
                                fontSize: 14,
                              ))),
                          Text.rich(TextSpan(
                              text: textState,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)))
                        ]),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (werror) ...[
                                Text.rich(
                                  TextSpan(
                                    text: 'Error: $errorMessage',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text.rich(
                                  TextSpan(
                                    text: 'Sintax: $errorSintax',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(children: [
                                const Text.rich(
                                  TextSpan(
                                    text: 'Red actual: ',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    text: nameOfWifi,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Color.fromARGB(255, 29, 163, 169),
                                    ),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              const Text.rich(
                                TextSpan(
                                  text: 'Ingrese los datos de WiFi',
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.qr_code),
                                iconSize: 50,
                                color: const Color.fromARGB(255, 29, 163, 169),
                                onPressed: () async {
                                  PermissionStatus permissionStatusC =
                                      await Permission.camera.request();
                                  if (!permissionStatusC.isGranted) {
                                    await Permission.camera.request();
                                  }
                                  permissionStatusC =
                                      await Permission.camera.status;
                                  if (permissionStatusC.isGranted) {
                                    openQRScanner(navigatorKey.currentContext!);
                                  }
                                },
                              ),
                              TextField(
                                style: const TextStyle(
                                    color: Color.fromARGB(255, 0, 0, 0)),
                                cursorColor:
                                    const Color.fromARGB(255, 29, 163, 169),
                                decoration: const InputDecoration(
                                  hintText: 'Nombre de la red',
                                  hintStyle: TextStyle(
                                      color: Color.fromARGB(255, 0, 0, 0)),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Color.fromARGB(255, 0, 0, 0)),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Color.fromARGB(255, 0, 0, 0)),
                                  ),
                                ),
                                onChanged: (value) {
                                  wifiName = value;
                                },
                              ),
                              TextField(
                                style: const TextStyle(
                                    color: Color.fromARGB(255, 0, 0, 0)),
                                cursorColor:
                                    const Color.fromARGB(255, 29, 163, 169),
                                decoration: const InputDecoration(
                                  hintText: 'Contraseña',
                                  hintStyle: TextStyle(
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Color.fromARGB(255, 0, 0, 0)),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Color.fromARGB(255, 0, 0, 0)),
                                  ),
                                ),
                                obscureText: true,
                                onChanged: (value) {
                                  wifiPassword = value;
                                },
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            style: const ButtonStyle(
                              foregroundColor: MaterialStatePropertyAll(
                                Color.fromARGB(255, 29, 163, 169),
                              ),
                            ),
                            child: const Text('Aceptar'),
                            onPressed: () {
                              sendWifitoBle();
                              navigatorKey.currentState?.pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ]),
        drawer: const DrawerDetector(),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                    height: 100,
                    width: width - 50,
                    decoration: BoxDecoration(
                      color: alert
                          ? Colors.red
                          : const Color.fromARGB(255, 0, 75, 81),
                      borderRadius: BorderRadius.circular(20),
                      border: const Border(
                        bottom: BorderSide(
                            color: Color.fromARGB(255, 24, 178, 199), width: 5),
                        right: BorderSide(
                            color: Color.fromARGB(255, 24, 178, 199), width: 5),
                        left: BorderSide(
                            color: Color.fromARGB(255, 24, 178, 199), width: 5),
                        top: BorderSide(
                            color: Color.fromARGB(255, 24, 178, 199), width: 5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _textToShow,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: alert ? Colors.white : Colors.green,
                            fontSize: 60),
                      ),
                    )),
                const SizedBox(
                  height: 20,
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 200,
                        width: (width/2) - 15,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 0, 75, 81),
                          borderRadius: BorderRadius.circular(20),
                          border: const Border(
                            bottom: BorderSide(
                                color: Color.fromARGB(255, 24, 178, 199),
                                width: 5),
                            right: BorderSide(
                                color: Color.fromARGB(255, 24, 178, 199),
                                width: 5),
                            left: BorderSide(
                                color: Color.fromARGB(255, 24, 178, 199),
                                width: 5),
                            top: BorderSide(
                                color: Color.fromARGB(255, 24, 178, 199),
                                width: 5),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'GAS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Atmósfera Explosiva',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${(ppmCH4 / 500).round()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 50,
                              ),
                            ),
                            const Text(
                              'LIE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Container(
                        height: 200,
                        width: (width/2) - 15,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 0, 75, 81),
                          borderRadius: BorderRadius.circular(20),
                          border: const Border(
                            bottom: BorderSide(
                                color: Color.fromARGB(255, 24, 178, 199),
                                width: 5),
                            right: BorderSide(
                                color: Color.fromARGB(255, 24, 178, 199),
                                width: 5),
                            left: BorderSide(
                                color: Color.fromARGB(255, 24, 178, 199),
                                width: 5),
                            top: BorderSide(
                                color: Color.fromARGB(255, 24, 178, 199),
                                width: 5),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'CO',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Monóxido de carbono',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '$ppmCO',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 50,
                              ),
                            ),
                            const Text(
                              'PPM',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 0, 75, 81),
                        borderRadius: BorderRadius.circular(50),
                        border: const Border(
                          bottom: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          right: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          left: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          top: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Pico máximo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'PPM CH4',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '$picoMaxppmCH4',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 30,
                            ),
                          ),
                          const Text(
                            'PPM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 0, 75, 81),
                        borderRadius: BorderRadius.circular(50),
                        border: const Border(
                          bottom: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          right: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          left: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          top: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Pico máximo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'PPM CO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '$picoMaxppmCO',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 30,
                            ),
                          ),
                          const Text(
                            'PPM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 15,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 0, 75, 81),
                        borderRadius: BorderRadius.circular(50),
                        border: const Border(
                          bottom: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          right: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          left: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          top: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Promedio',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'PPM CH4',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '$promedioppmCH4',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 30,
                            ),
                          ),
                          const Text(
                            'PPM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 0, 75, 81),
                        borderRadius: BorderRadius.circular(50),
                        border: const Border(
                          bottom: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          right: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          left: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                          top: BorderSide(
                              color: Color.fromARGB(255, 24, 178, 199),
                              width: 5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Promedio',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'PPM CO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '$promedioppmCO',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 30,
                            ),
                          ),
                          const Text(
                            'PPM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 15,
                ),
                Container(
                    height: 80,
                    width: 350,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 75, 81),
                      borderRadius: BorderRadius.circular(20),
                      border: const Border(
                        bottom: BorderSide(
                            color: Color.fromARGB(255, 24, 178, 199), width: 5),
                        right: BorderSide(
                            color: Color.fromARGB(255, 24, 178, 199), width: 5),
                        left: BorderSide(
                            color: Color.fromARGB(255, 24, 178, 199), width: 5),
                        top: BorderSide(
                            color: Color.fromARGB(255, 24, 178, 199), width: 5),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Estado: ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 30,
                              ),
                            ),
                            Text(online ? 'EN LINEA' : 'DESCONECTADO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: online ? Colors.green : Colors.red,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold))
                          ],
                        ),
                        Text(
                          'El certificado del sensor caduca en: $daysToExpire dias',
                          style: const TextStyle(
                              fontSize: 15.0, color: Colors.white),
                        ),
                      ],
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
