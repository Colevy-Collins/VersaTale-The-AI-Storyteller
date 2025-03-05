import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StoryService {
  // Replace with your actual backend URL.
  final String backendUrl = "http://localhost:8080";
  final AuthService authService = AuthService();

  /// Starts a new story by sending full story options to the backend.
  /// Expects a JSON payload with: decision, genre, setting, tone, maxLegs, and optionCount.
  /// Returns a Map containing:
  /// - "storyLeg": The first generated story leg.
  /// - "options": A list of options provided by the AI.
  Future<Map<String, dynamic>> startStory({
    required String decision,
    required String genre,
    required String setting,
    required String tone,
    required int maxLegs,
    required int optionCount,
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
      "optionCount": optionCount,
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
      return {
        "storyLeg": data["aiResponse"]["storyLeg"] ?? "No story leg returned.",
        "options": data["aiResponse"]["options"] ?? [],
      };
    } else {
      throw Exception("Backend error: ${response.statusCode}");
    }
  }

  /// Sends the user's decision to generate the next story leg.
  /// Expects a JSON payload with only the decision.
  /// Returns a Map containing:
  /// - "storyLeg": The next generated story leg.
  /// - "options": A list of options provided by the AI.
  Future<Map<String, dynamic>> getNextLeg({required String decision}) async {
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
      return {
        "storyLeg": data["aiResponse"]["storyLeg"] ?? "No story leg returned.",
        "options": data["aiResponse"]["options"] ?? [],
      };
    } else {
      throw Exception("Backend error: ${response.statusCode}");
    }
  }
}
