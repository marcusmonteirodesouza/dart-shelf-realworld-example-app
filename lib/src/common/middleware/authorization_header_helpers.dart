import 'package:dart_shelf_realworld_example_app/src/users/jwt_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_service.dart';

import '../../users/model/user.dart';

Future<User?> getUserFromAuthorizationHeader(UsersService usersService,
    JwtService jwtService, String? authorizationHeader) async {
  if (authorizationHeader == null) {
    return null;
  }

  if (!authorizationHeader.startsWith('Token ')) {
    return null;
  }

  final token = authorizationHeader.replaceFirst('Token', '').trim();

  if (token.isEmpty) {
    return null;
  }

  final userTokenClaim = jwtService.getUserTokenClaim(token);

  if (userTokenClaim == null) {
    return null;
  }

  return await usersService.getUserByEmail(userTokenClaim.email);
}
