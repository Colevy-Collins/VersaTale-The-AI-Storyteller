import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StoryService {
  // Replace with your actual backend URL.
  final String backendUrl = "http://localhost:8080"; //"https://cloud-run-backend-706116508486.us-central1.run.app"; //"http://localhost:8080";
  final AuthService authService = AuthService();

  Future<Map<String, dynamic>> startStory({
    required String decision,
    required Map<String, dynamic> dimensionData,
    required int maxLegs,
    required int optionCount,
    required String storyLength,
  }) async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }

    final url = Uri.parse("$backendUrl/start_story");

    // Construct the JSON payload including all dimensions.
    final payload = jsonEncode({
      "decision": decision,
      "dimensions": dimensionData,
      "maxLegs": maxLegs,
      "optionCount": optionCount,
      "storyLength": storyLength,
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
      final errorMessage =
      response.body.isNotEmpty ? response.body : "Unknown error occurred.";
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

  Future<Map<String, dynamic>> getPreviousLeg() async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }

    // Update this URL path to match your backend route for going back one leg.
    final url = Uri.parse("$backendUrl/previous_leg");

    // Here, we assume no special payload is needed; if your backend needs data,
    // add it to 'body' and set the method accordingly (POST/GET).
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        "storyLeg": data["aiResponse"]["storyLeg"] ?? "No story leg returned.",
        "options": data["aiResponse"]["options"] ?? [],
        "storyTitle": data["aiResponse"]["storyTitle"] ?? "Untitled Story",
      };
    } else {
      String errorMessage =
      response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
    }
  }

  Future<Map<String, dynamic>> getFullStory() async {
    final token = await authService.getToken();
    if (token == null) {
      throw Exception("User is not authenticated.");
    }
    final url = Uri.parse("$backendUrl/story");

    // Because it's a GET endpoint, we just call .get() with the required headers
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Example structure: data could contain the entire story in "initialLeg",
      // the current options in "options", and the story title in "storyTitle".
      return data;
    } else {
      String errorMessage = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
      throw Exception("Error: $errorMessage");
    }
  }




}
