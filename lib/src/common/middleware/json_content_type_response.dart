import 'package:shelf/shelf.dart';

Middleware jsonContentTypeResponse() => (innerHandler) {
      return (request) async {
        final response = await innerHandler(request);

        final contentTypeJson = {
          'content-type': 'application/json; charset=utf-8'
        };

        return response
            .change(headers: {...response.headersAll, ...contentTypeJson});
      };
    };
