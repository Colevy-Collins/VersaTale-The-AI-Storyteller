import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StoryService {
  // Replace with your actual backend URL.
  final String backendUrl = "http://localhost:8080"; //"https://cloud-run-backend-706116508486.us-central1.run.app";
  final AuthService authService = AuthService();

  /// Starts a new story by sending full story options to the backend.
  /// Expects a JSON payload with: decision, genre, setting, tone, and maxLegs.
  /// Returns the first generated story leg.
  Future<String> startStory({
    required String decision,
    required String genre,
    required String setting,
    required String tone,
    required int maxLegs,
  }) async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }
    final url = Uri.parse("$backendUrl/start_story");
    final payload = jsonEncode({
      "decision": decision,
      "genre": genre,
      "setting": setting,
      "tone": tone,
      "maxLegs": maxLegs,
    });
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: payload,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["newLeg"] ?? "No story leg returned.";
    } else {
      throw Exception("Backend error: ${response.statusCode}");
    }
  }

  /// Sends the user's decision to generate the next story leg.
  /// Expects a JSON payload with only the decision.
  /// Returns the next generated story leg.
  Future<String> getNextLeg({required String decision}) async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }
    final url = Uri.parse("$backendUrl/next_leg");
    final payload = jsonEncode({
      "decision": decision,
    });
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: payload,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["newLeg"] ?? "No story leg returned.";
    } else {
      throw Exception("Backend error: ${response.statusCode}");
    }
  }
}
