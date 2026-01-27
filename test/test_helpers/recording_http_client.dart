import 'package:http/http.dart' as http;

class RecordingHttpClient extends http.BaseClient {
  RecordingHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return _handler(request);
  }
}
