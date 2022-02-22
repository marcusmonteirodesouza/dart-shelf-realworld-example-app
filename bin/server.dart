import 'dart:io';

import 'package:dart_shelf_realworld_example_app/app.dart';

Future<void> main(List<String> args) async {
  final server = await createServer();

  ProcessSignal.sigint.watch().listen((signal) async {
    print('SIGINT received. Closing the server...');
    await server.close();
    print('Server closed. Exiting...');
    exit(0);
  });
}
