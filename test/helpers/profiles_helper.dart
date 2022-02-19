import 'dart:convert';

import 'package:dart_shelf_realworld_example_app/src/profiles/dtos/profile_dto.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import '../test_fixtures.dart';
import 'auth_helper.dart';

Uri getProfileUriByUsername(String username) {
  return Uri.parse(host + '/profiles/$username');
}

Future<Response> getProfileByUsername(String username, {String? token}) async {
  Map<String, String> headers = {};

  if (token != null) {
    headers = makeAuthorizationHeader(token);
  }

  return await get(getProfileUriByUsername(username), headers: headers);
}

Future<ProfileDto> getProfileByUsernameAndDecode(String username,
    {String? token}) async {
  var response = await getProfileByUsername(username, token: token);

  expect(response.statusCode, 200);

  final responseJson = jsonDecode(response.body);

  final profile = ProfileDto.fromJson(responseJson);

  return profile;
}

Uri followUserByUsernameUri(String username) {
  return Uri.parse(host + '/profiles/$username/follow');
}

Future<Response> followUserByUsername(String username,
    {required String token}) async {
  var headers = makeAuthorizationHeader(token);

  return await post(followUserByUsernameUri(username), headers: headers);
}

Future<ProfileDto> followUserByUsernameAndDecode(String username,
    {required String token}) async {
  var response = await followUserByUsername(username, token: token);

  expect(response.statusCode, 200);

  final responseJson = jsonDecode(response.body);

  return ProfileDto.fromJson(responseJson);
}

Uri unfollowUserUri(String username) {
  return Uri.parse(host + '/profiles/$username/follow');
}

Future<Response> unfollowUserByUsername(String username,
    {required String token}) async {
  var headers = makeAuthorizationHeader(token);

  return await delete(unfollowUserUri(username), headers: headers);
}

Future<ProfileDto> unfollowUserByUsernameAndDecode(String username,
    {required String token}) async {
  var response = await unfollowUserByUsername(username, token: token);

  expect(response.statusCode, 200);

  final responseJson = jsonDecode(response.body);

  return ProfileDto.fromJson(responseJson);
}
