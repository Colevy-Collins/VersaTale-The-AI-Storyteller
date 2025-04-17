import 'dart:convert';
import 'dart:io'; // Needed to catch SocketException.
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
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/start_story");
    final payload = jsonEncode({
      "decision": decision,
      "dimensions": dimensionData,
      "maxLegs": maxLegs,
      "optionCount": optionCount,
      "storyLength": storyLength,
    });
    try {
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
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>> getNextLeg({required String decision}) async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/next_leg");
    final payload = jsonEncode({
      "decision": decision,
    });
    try {
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
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>> saveStory() async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/save_story");
    try {
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
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<List<dynamic>> getSavedStories() async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/saved_stories");
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["stories"] as List<dynamic>;
      } else {
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>?> getActiveStory() async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/story");
    try {
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
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>> viewStory({required String storyId}) async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/view_story?storyId=$storyId");
    try {
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
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<bool> deleteStory({required String storyId}) async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/delete_story");
    final payload = jsonEncode({
      "storyId": "$storyId",
    });
    try {
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
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>> continueStory({required String storyId}) async {
    final token = await authService.getToken();
    print("storyId: $storyId");
    if (token == null) {
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/continue_story");
    final payload = jsonEncode({
      "storyId": "$storyId",
    });
    try {
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
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>> getPreviousLeg() async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/previous_leg");
    try {
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
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>> getFullStory() async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }
    final url = Uri.parse("$backendUrl/story");
    try {
      final response = await http.get(
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
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }

    // Suppose your backend has an endpoint like /profile that returns JSON:
    // {
    //   "creationDate": "...",
    //   "lastAccessDate": "...",
    //   ...
    // }
    final url = Uri.parse("$backendUrl/profile");

    try {
      final response = await http.get(
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
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<void> deleteUserData() async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }

    final url = Uri.parse("$backendUrl/delete_user_data");

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // success
        return;
      } else {
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<bool> deleteAllStories() async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }

    // Adjust this to match your actual backend endpoint for deleting all stories.
    final url = Uri.parse("$backendUrl/delete_all_stories");

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final responseBody = response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        final decoded = jsonDecode(responseBody);

        if (decoded["message"] != null) {
          throw decoded["message"];
        } else {
          throw responseBody;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<void> updateLastAccessDate() async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }

    final url = Uri.parse("$backendUrl/update_last_access");

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Success
        return;
      } else {
        final errorMessage =
        response.body.isNotEmpty ? response.body : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }





  /// Creates a new multiplayer session by sending dimension data to the backend.
  /// The backend should generate a join code and create the session, then return:
  /// { "joinCode": ..., "sessionId": ..., "storyState": ... }
  Future<Map<String, dynamic>> createMultiplayerSession({
    required Map<String, dynamic> dimensionData,
  }) async {
    final token = await authService.getToken();
    if (token == null) {
      throw "User is not authenticated.";
    }

    // Adjust the endpoint as needed.
    final url = Uri.parse("$backendUrl/create_multiplayer_session");
    final payload = jsonEncode({
      "dimensions": dimensionData,
    });

    try {
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
          "joinCode": data["joinCode"],
          "sessionId": data["sessionId"],
          "storyState": data["storyState"] ?? {},
        };
      } else {
        final errorMessage = response.body.isNotEmpty
            ? response.body
            : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }



  /// Submit votes for a session’s story leg.
  /// This is where you do your tie-break logic as well.
  Future<Map<String, dynamic>> submitVotes({
    required String sessionId,
    required Map<String, String> playerVotes,
    required String hostTieBreakChoice,
  }) async {
    // 1. Tally votes
    // 2. If tie => use hostTieBreakChoice
    // 3. Generate next story leg from your AI or rules
    // 4. Return the updated story state
    return {
      "storyLeg": "Some new leg text",
      "options": ["Option A", "Option B"],
    };
  }
  /// Join an existing multiplayer session by join code.
  /// Returns the session details, including players and storyState.
  Future<Map<String, dynamic>> joinMultiplayerSession({
    required String joinCode,
    required String displayName,
  }) async {
    final token = await authService.getToken();
    if (token == null) throw "User is not authenticated.";
    final url = Uri.parse("$backendUrl/join_multiplayer_session");

    final payload = jsonEncode({
      "joinCode": joinCode,
      "displayName": displayName,
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
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final body = response.body;
      String msg;
      try {
        final data = jsonDecode(body);
        msg = data['message'] ?? body;
      } catch (_) {
        msg = body;
      }
      throw msg;
    }
  }



  Future<Map<String, dynamic>> startGroupStory(Map<String, dynamic> payload) async {
    final token = await authService.getToken();
    if (token == null) throw "Not authenticated";
    final url = Uri.parse("$backendUrl/create_multiplayer_session");

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "joinCode": data["joinCode"],
          "sessionId": data["sessionId"],
          "storyState": data["storyState"] ?? {},
          "players": data["players"]  ?? {},
        };
      } else {
        final errorMessage = response.body.isNotEmpty
            ? response.body
            : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>> fetchLobbyState(String sessionId) async {
    final token = await authService.getToken();
    if (token == null) throw "User is not authenticated.";
    final url = Uri.parse("$backendUrl/lobby_state?sessionId=$sessionId");

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = response.body;
      String msg;
      try {
        final data = jsonDecode(body);
        msg = data['message'] ?? body;
      } catch (_) {
        msg = body;
      }
      throw msg;
    }
  }

  Future<Map<String, dynamic>> updatePlayerName(Map<String, dynamic> payload) async {
    final token = await authService.getToken();
    if (token == null) throw "Not authenticated";
    final url = Uri.parse("$backendUrl/update_player_name");

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "joinCode": data["joinCode"],
          "sessionId": data["sessionId"],
          "storyState": data["storyState"] ?? {},
          "players": data["players"]  ?? {},
        };
      } else {
        final errorMessage = response.body.isNotEmpty
            ? response.body
            : "Unknown error occurred.";
        if (jsonDecode(response.body)["message"] != null) {
          throw jsonDecode(response.body)["message"];
        } else {
          throw errorMessage;
        }
      }
    } on SocketException catch (_) {
      throw "Server is unavailable or unreachable.";
    } catch (e) {
      if (e is http.ClientException) {
        throw "Server is unavailable or unreachable. \n $e";
      } else if (e.toString().contains("Route not found")) {
        throw "Server route is not available.";
      } else {
        throw "$e";
      }
    }
  }

  Future<Map<String, dynamic>> submitVote(Map<String, String> vote) async {
    final token = await authService.getToken();
    if (token == null) throw "Not authenticated";
    final response = await http.post(
      Uri.parse('$backendUrl/submit_vote'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'vote': vote}),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to submit vote');
    }
    return jsonDecode(response.body);
  }

  /// Called by **host** to resolve all votes.
  /// Server should tally votes, break ties, and return:
  /// { "resolvedDimensions": { dimKey: winningOption, ... } }
  Future<Map<String, dynamic>> resolveVotes(String sessionId) async {
    final token = await authService.getToken();
    if (token == null) throw "Not authenticated";
    final res = await http.post(
      Uri.parse('$backendUrl/resolve_votes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({ 'sessionId': sessionId }),
    );
    return jsonDecode(res.body);
  }








}
