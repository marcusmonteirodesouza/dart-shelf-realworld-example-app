import 'dart:convert';

import 'package:dart_shelf_realworld_example_app/src/common/errors/dtos/error_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/already_exists_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/argument_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/users/dtos/user_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/users/jwt_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'model/user.dart';

part 'users_service.g.dart';

class UsersService {
  final UsersRepository usersRepository;
  final JwtService jwtService;

  UsersService({required this.usersRepository, required this.jwtService});

  @Route.post('/users')
  Future<Response> registerUserHandler(Request request) async {
    final requestBody = await request.readAsString();
    final requestData = json.decode(requestBody);

    final userData = requestData['user'];

    if (userData == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['user is required'])));
    }

    final username = userData['username'];
    final email = userData['email'];
    final password = userData['password'];

    if (username == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['username is required'])));
    }

    if (email == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['email is required'])));
    }

    if (password == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['password is required'])));
    }

    User user;

    try {
      user = await usersRepository.createUser(username, email, password);
    } on ArgumentException catch (e) {
      return Response(422, body: jsonEncode(ErrorDto(errors: [e.message])));
    } on AlreadyExistsException catch (e) {
      return Response(409, body: jsonEncode(ErrorDto(errors: [e.message])));
    }

    final token = jwtService.getToken(user.email);

    final userDto =
        UserDto(username: user.username, email: user.email, token: token);

    return Response(201, body: jsonEncode(userDto));
  }

  @Route.post('/users/login')
  Future<Response> loginUserHandler(Request request) async {
    final requestBody = await request.readAsString();
    final requestData = json.decode(requestBody);

    final userData = requestData['user'];

    if (userData == null) {
      return Response(401);
    }

    final email = userData['email'];
    final password = userData['password'];

    if (email == null) {
      return Response(401);
    }

    if (password == null) {
      return Response(401);
    }

    final user =
        await usersRepository.getUserByEmailAndPassword(email, password);

    if (user == null) {
      return Response(401);
    }

    final token = jwtService.getToken(user.email);

    final userDto = UserDto(
        username: user.username,
        email: user.email,
        token: token,
        bio: user.bio,
        image: user.image);

    return Response.ok(jsonEncode(userDto));
  }

  @Route.get('/user')
  Future<Response> getCurrentUserHandler(Request request) async {
    final user = request.context['user'] as User;

    final token = jwtService.getToken(user.email);

    final userDto = UserDto(
        username: user.username,
        email: user.email,
        token: token,
        bio: user.bio,
        image: user.image);

    return Response.ok(jsonEncode(userDto));
  }

  @Route.put('/user')
  Future<Response> updateUserHandler(Request request) async {
    final user = request.context['user'] as User;

    final requestBody = await request.readAsString();
    final requestData = json.decode(requestBody);

    final userData = requestData['user'];
    final username = userData['username'];
    final emailForUpdate = userData['email'];
    final password = userData['password'];
    final bio = userData['bio'];
    final image = userData['image'];

    final updatedUser = await usersRepository.updateUserByEmail(user.email,
        username: username,
        emailForUpdate: emailForUpdate,
        password: password,
        bio: bio,
        image: image);

    final token = jwtService.getToken(updatedUser.email);

    final userDto = UserDto(
        username: updatedUser.username,
        email: updatedUser.email,
        token: token,
        bio: updatedUser.bio,
        image: updatedUser.image);

    return Response.ok(jsonEncode(userDto));
  }

  // Create router using the generate function defined in 'userservice.g.dart'.
  Router get router => _$UsersServiceRouter(this);
}
