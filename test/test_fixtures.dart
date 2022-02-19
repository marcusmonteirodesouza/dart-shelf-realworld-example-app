import 'package:faker/faker.dart';

final faker = Faker();

final port = 8080;

final authority = 'localhost:$port';

final apiPath = 'api';

final host = 'http://$authority/$apiPath';

final secretKey = 'secret';

final issuer = 'https://conduit/api';
