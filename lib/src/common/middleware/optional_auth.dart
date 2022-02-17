import 'package:dart_shelf_realworld_example_app/src/common/middleware/authorization_header_helpers.dart';
import 'package:dart_shelf_realworld_example_app/src/users/jwt_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_service.dart';
import 'package:shelf/shelf.dart';

Middleware optionalAuth(
  UsersService usersService,
  JwtService jwtService,
) =>
    (innerHandler) {
      return (request) async {
        final authorizationHeader = request.headers['Authorization'] ??
            request.headers['authorization'];

        final user = await getUserFromAuthorizationHeader(
            usersService, jwtService, authorizationHeader);

        if (user != null) {
          request = request.change(context: {'user': user});
        }

        return Future.sync(() => innerHandler(request)).then((response) {
          return response;
        });
      };
    };
