import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StoryService {
  // Replace with your actual backend URL.
  final String backendUrl = "https://cloud-run-backend-706116508486.us-central1.run.app";
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
        "storyTitle": data["aiResponse"]["storyTitle"] ?? "Untitled Story",
      };
    } else {
      // Use the error message from the response body if available.
      String errorMessage = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
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
        "storyTitle": data["aiResponse"]["storyTitle"] ?? "Untitled Story",
      };
    } else {
      String errorMessage = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
    }
  }

  /// Sends a request to save the current story to the backend.
  Future<Map<String, dynamic>> saveStory() async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }
    final url = Uri.parse("$backendUrl/save_story");
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      String errorMessage = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
    }
  }

  Future<List<dynamic>> getSavedStories() async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }
    final url = Uri.parse("$backendUrl/saved_stories");
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["stories"] as List<dynamic>;
    } else {
      String errorMessage = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
    }
  }

  /// Retrieves the currently active story from the backend.
  /// Expects a JSON payload with keys "initialLeg", "options", and "storyTitle".
  Future<Map<String, dynamic>?> getActiveStory() async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }
    final url = Uri.parse("$backendUrl/story");
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(data);
      return {
        "storyLeg": data["initialLeg"] ?? "No story leg returned.",
        "options": data["options"] ?? [],
        "storyTitle": data["storyTitle"] ?? "Untitled Story",
      };
    } else {
      String errorMessage = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
    }
  }

  /// Retrieves full details of a saved story by its ID.
  Future<Map<String, dynamic>> viewStory({required String storyId}) async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }
    final url = Uri.parse("$backendUrl/view_story?storyId=$storyId");
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(data);
      return data;
    } else {
      String errorMessage = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
    }
  }

  /// Deletes a saved story by its ID.
  Future<bool> deleteStory({required String storyId}) async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }
    final url = Uri.parse("$backendUrl/delete_story");
    final payload = jsonEncode({
      "storyId": "$storyId",
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
      return true;
    } else {
      String errorMessage = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
    }
  }

  /// Loads a saved story into active memory on the server using its ID,
  /// and returns the active story details including the story leg, options, and title.
  Future<Map<String, dynamic>> continueStory({required String storyId}) async {
    final token = await authService.getToken();
    print("storyId: $storyId");
    if (token == null) {
      throw Exception("User is not authenticated.");
    }
    final url = Uri.parse("$backendUrl/continue_story");
    final payload = jsonEncode({
      "storyId": "$storyId",
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
        "storyLeg": data["initialLeg"] ?? "No story leg returned.",
        "options": data["options"] ?? [],
        "storyTitle": data["storyTitle"] ?? "Untitled Story",
      };
    } else {
      String errorMessage = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
    }
  }
}
