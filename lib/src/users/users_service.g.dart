// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_service.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$UsersServiceRouter(UsersService service) {
  final router = Router();
  router.add('POST', r'/users', service.registerUserHandler);
  router.add('POST', r'/users/login', service.loginUserHandler);
  router.add('GET', r'/user', service.getCurrentUserHandler);
  router.add('PUT', r'/user', service.updateUserHandler);
  return router;
}
