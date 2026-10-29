import 'package:dio/dio.dart';
import 'package:policysquare/api/api_client.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(_readableError(e, 'log in'));
    }
  }

  Future<Map<String, dynamic>> signup(String username, String email, String mobile, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/auth/signup',
        data: {
          'username': username,
          'email': email,
          'mobileNumber': mobile,
          'password': password,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(_readableError(e, 'sign up'));
    }
  }

  /// The server explains refusals precisely — a taken username, a malformed
  /// field — so surface that text rather than the transport error wrapping it.
  String _readableError(DioException error, String action) {
    final data = error.response?.data;
    if (data is Map) {
      final messages = data.values.map((value) => value.toString()).join('\n');
      if (messages.isNotEmpty) return messages;
    } else if (data is String && data.isNotEmpty) {
      return data;
    }
    return 'Could not $action. The server could not be reached — check that it '
        'is still running, then try again.';
  }
}
