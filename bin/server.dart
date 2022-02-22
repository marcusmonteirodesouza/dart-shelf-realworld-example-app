import 'dart:async';
import 'dart:io';

import 'package:dart_shelf_realworld_example_app/src/api_router.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/articles_router.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/articles_service.dart';
import 'package:dart_shelf_realworld_example_app/src/common/middleware/auth.dart';
import 'package:dart_shelf_realworld_example_app/src/profiles/profiles_router.dart';
import 'package:dart_shelf_realworld_example_app/src/profiles/profiles_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/jwt_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_router.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_service.dart';
import 'package:dotenv/dotenv.dart';
import 'package:postgres_pool/postgres_pool.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

Future main(List<String> args) async {
  var environment = Platform.environment['ENVIRONMENT'] ?? 'local';

  environment = environment.trim().toLowerCase();

  if (environment == 'local') {
    load();
  }

  final authSecretKey = env['AUTH_SECRET_KEY'];
  final authIssuer = env['AUTH_ISSUER'];
  var dbHost = env['DB_HOST'];
  final envDbPort = env['DB_PORT'];
  final dbName = env['DB_NAME'];
  final dbUser = env['DB_USER'];
  final dbPassword = env['DB_PASSWORD'];
  final isUnixSocket = env['USE_UNIX_SOCKET'] != null ? true : false;

  if (authSecretKey == null) {
    throw StateError('Environment variable AUTH_SECRET_KEY is required');
  }

  if (authIssuer == null) {
    throw StateError('Environment variable AUTH_ISSUER is required');
  }

  if (dbHost == null) {
    throw ArgumentError('Environment variable DB_HOST is required');
  }

  if (envDbPort == null) {
    throw StateError('Environment variable DB_PORT is required');
  }

  if (dbName == null) {
    throw StateError('Environment variable DB_NAME is required');
  }

  final dbPort = int.tryParse(envDbPort);

  if (dbPort == null) {
    throw ArgumentError('Environment variable DB_PORT must be an integer');
  }

  if (isUnixSocket) {
    dbHost = dbHost + '/.s.PGSQL.$dbPort';
  }

  final connectionPool = PgPool(PgEndpoint(
      host: dbHost,
      port: dbPort,
      database: dbName,
      username: dbUser,
      password: dbPassword,
      isUnixSocket: isUnixSocket));

  print('Connecting to the database...');

  // Validation query
  final validationQueryResult = await connectionPool.query('SELECT version();');

  print('Connected to the database. ${validationQueryResult[0][0]}');

  final usersService = UsersService(connectionPool: connectionPool);
  final jwtService = JwtService(issuer: authIssuer, secretKey: authSecretKey);
  final profilesService = ProfilesService(
      connectionPool: connectionPool, usersService: usersService);
  final articlesService = ArticlesService(
      connectionPool: connectionPool, usersService: usersService);

  final authProvider =
      AuthProvider(usersService: usersService, jwtService: jwtService);

  final usersRouter = UsersRouter(
      usersService: usersService,
      jwtService: jwtService,
      authProvider: authProvider);
  final profilesRouter = ProfilesRouter(
      profilesService: profilesService,
      usersService: usersService,
      authProvider: authProvider);
  final articlesRouter = ArticlesRouter(
      articlesService: articlesService,
      usersService: usersService,
      profilesService: profilesService,
      authProvider: authProvider);

  final apiRouter = ApiRouter(
          usersRouter: usersRouter,
          profilesRouter: profilesRouter,
          articlesRouter: articlesRouter)
      .router;

  // Configure a pipeline that logs requests.
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(apiRouter);

  // See https://cloud.google.com/run/docs/reference/container-contract#port
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final server = await serve(handler, InternetAddress.anyIPv4, port);

  print('Server listening at http://${server.address.host}:${server.port}');

  await terminateRequestFuture();

  await connectionPool.close();

  await server.close();
}

/// Returns a [Future] that completes when the process receives a
/// [ProcessSignal] requesting a shutdown.
///
/// [ProcessSignal.sigint] is listened to on all platforms.
///
/// [ProcessSignal.sigterm] is listened to on all platforms except Windows.
Future<void> terminateRequestFuture() {
  final completer = Completer<bool>.sync();

  // sigIntSub is copied below to avoid a race condition - ignoring this lint
  // ignore: cancel_subscriptions
  StreamSubscription? sigIntSub, sigTermSub;

  Future<void> signalHandler(ProcessSignal signal) async {
    print('Received signal $signal - closing');

    final subCopy = sigIntSub;
    if (subCopy != null) {
      sigIntSub = null;
      await subCopy.cancel();
      sigIntSub = null;
      if (sigTermSub != null) {
        await sigTermSub!.cancel();
        sigTermSub = null;
      }
      completer.complete(true);
    }
  }

  sigIntSub = ProcessSignal.sigint.watch().listen(signalHandler);

  // SIGTERM is not supported on Windows. Attempting to register a SIGTERM
  // handler raises an exception.
  if (!Platform.isWindows) {
    sigTermSub = ProcessSignal.sigterm.watch().listen(signalHandler);
  }

  return completer.future;
}
