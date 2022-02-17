import 'package:dart_shelf_realworld_example_app/src/users/users_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class ApiService {
  // Routes without the starting slash
  static List<String> routesRequiringAuthorization = ['api/user'];

  final UsersService usersService;

  ApiService({required this.usersService});

  Handler get router {
    final prefix = '/api';

    final router = Router();

    router.mount(prefix, usersService.router);

    return router;
  }
}
