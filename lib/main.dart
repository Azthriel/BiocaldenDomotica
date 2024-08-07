// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import '020010/device_inout.dart';
import 'firebase_options.dart';
import 'aws/mqtt/mqtt.dart';
import 'stored_data.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '015773/device_detector.dart';
import 'calefactores/device_calefactor.dart';
import 'login/login.dart';
import 'master.dart';
import 'scan.dart';
import 'calefactores/device_silema.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'amplifyconfiguration.dart';

Future<void> main() async {
  appName = biocalden ? 'Biocalden Smart Life' : 'Silema Calefacción';
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (FlutterErrorDetails details) async {
    String errorReport = generateErrorReport(details);
    sendReportError(errorReport);
  };

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: true,
      builder: (BuildContext context) {
        String displayMessage = message.notification?.body.toString() ??
            'Un equipo mando una alerta';
        String displayTitle =
            message.notification?.title.toString() ?? '¡ALERTA EN EQUIPO!';

        return AlertDialog(
            backgroundColor: const Color(0xFF1E242B),
            title: Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFFF0000), fontWeight: FontWeight.bold),
            ),
            content: Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB2B5AE)),
            ));
      },
    );
    printLog('Llegó esta notif: $message');
  });

  runApp(
    ChangeNotifierProvider(
      create: (context) => GlobalDataNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    //! IOS O ANDROID !\\
    android = Platform.isIOS;
    //! IOS O ANDROID !\\

    loadValues();
    _configureAmplify();
    setupMqtt().then((value) {
      if (value) {
        for (var topic in topicsToSub) {
          printLog('Subscribiendo a $topic');
          subToTopicMQTT(topic);
        }
      }
    });
    listenToTopics();
    printLog('Empezamos');
  }

  void _configureAmplify() async {
    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(amplifyconfig);
      printLog('Successfully configured');
    } on Exception catch (e) {
      printLog('Error configuring Amplify: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: biocalden ? 'Biocalden Smart Life' : 'Silema Calefacción',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E242B),
        primaryColorLight: const Color(0xFFB2B5AE),
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Color(0xFFB2B5AE),
          selectionHandleColor: Color(0xFFB2B5AE),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E242B)),
        useMaterial3: true,
      ),
      initialRoute: '/perm',
      routes: {
        '/perm': (context) => const PermissionHandler(),
        '/login': (context) => const LoginPage(),
        '/scan': (context) => android ? const ScanPage() : const IOSScanPage(),
        '/loading': (context) =>
            android ? const LoadingPage() : const IOSLoadingPage(),
        '/calefactor': (context) => android ? const ControlPage() : const IOSControlPage(),
        '/detector': (context) =>
            android ? const DetectorPage() : const IOSDetector(),
        '/radiador': (context) =>
            android ? const RadiadorPage() : const IOSRadiadorPage(),
        '/io': (context) => android ? const IODevices() : const IOSIODevices(),
      },
    );
  }
}

//PERMISOS //PRIMERA PARTE

class PermissionHandler extends StatefulWidget {
  const PermissionHandler({super.key});

  @override
  PermissionHandlerState createState() => PermissionHandlerState();
}

class PermissionHandlerState extends State<PermissionHandler> {
  Future<Widget> permissionCheck() async {
    var permissionStatus1 = await Permission.bluetoothConnect.request();

    if (!permissionStatus1.isGranted) {
      await Permission.bluetoothConnect.request();
    }
    permissionStatus1 = await Permission.bluetoothConnect.status;

    var permissionStatus2 = await Permission.bluetoothScan.request();

    if (!permissionStatus2.isGranted) {
      await Permission.bluetoothScan.request();
    }
    permissionStatus2 = await Permission.bluetoothScan.status;

    var permissionStatus3 = await Permission.location.request();

    if (!permissionStatus3.isGranted) {
      await Permission.location.request();
    }
    permissionStatus3 = await Permission.location.status;

    requestPermissionFCM();

    if (permissionStatus1.isGranted &&
        permissionStatus2.isGranted &&
        permissionStatus3.isGranted) {
      return const AskLoginPage();
    } else {
      return AlertDialog(
        title: const Text('Permisos requeridos'),
        content: const Text(
            'No se puede seguir sin los permisos\n Por favor activalos manualmente'),
        actions: [
          TextButton(
            child: const Text('Abrir opciones de la app'),
            onPressed: () => openAppSettings(),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${snapshot.error} occured',
                style: const TextStyle(fontSize: 18),
              ),
            );
          } else {
            return snapshot.data as Widget;
          }
        }
        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFBDBDBD),
          ),
        );
      },
      future: permissionCheck(),
    );
  }
}
