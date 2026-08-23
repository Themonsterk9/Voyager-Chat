import '../api_client.dart';
import '../api_endpoints.dart';

class HealthService {
  Future<bool> checkBackend() async {
    try {
      final response = await ApiClient.instance.dio.get(ApiEndpoints.health);

      return response.statusCode == 200 &&
          response.data is Map &&
          response.data['status'] == 'OK';
    } catch (_) {
      return false;
    }
  }
}
