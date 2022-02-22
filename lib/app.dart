import 'dart:io';

import 'package:dart_shelf_realworld_example_app/src/api_router.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/articles_router.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/articles_service.dart';
import 'package:dart_shelf_realworld_example_app/src/common/middleware/auth.dart';
import 'package:dart_shelf_realworld_example_app/src/profiles/profiles_router.dart';
import 'package:dart_shelf_realworld_example_app/src/profiles/profiles_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/jwt_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_router.dart';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

Future<HttpServer> createServer() async {
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

  final connection = PostgreSQLConnection(dbHost, dbPort, dbName,
      username: dbUser, password: dbPassword, isUnixSocket: isUnixSocket);

  print('Connecting to the database...');

  await connection.open();

  // Validation query
  final validationQueryResult = await connection.query('SELECT version();');

  print('Connected to the database. ${validationQueryResult[0][0]}');

  final usersService = UsersService(connection: connection);
  final jwtService = JwtService(issuer: authIssuer, secretKey: authSecretKey);
  final profilesService =
      ProfilesService(connection: connection, usersService: usersService);
  final articlesService =
      ArticlesService(connection: connection, usersService: usersService);

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

  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(apiRouter);

  final port = int.parse(env['PORT'] ?? '8080');

  // For running in containers, we respect the PORT environment variable.
  final server = await serve(handler, ip, port);

  print('Server listening on port ${server.port}');

  return server;
}
