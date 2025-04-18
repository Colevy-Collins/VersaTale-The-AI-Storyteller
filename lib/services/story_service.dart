import 'dart:convert';
import 'dart:io'; // Needed to catch SocketException.
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'lobby_rtdb_service.dart';

class StoryService {
  // Replace with your actual backend URL.
  final String backendUrl = "http://localhost:8080"; //"https://cloud-run-backend-706116508486.us-central1.run.app"; //"http://localhost:8080";
  final AuthService authService = AuthService();

/*─────────────────────────  S O L O  +  S T O R Y  ─────────────────────────*/

  Future<Map<String, dynamic>> startStory({
    required String decision,
    required Map<String, dynamic> dimensionData,
    required int maxLegs,
    required int optionCount,
    required String storyLength,
  }) async {
    final token = await authService.getToken();
    if (token == null) throw "User is not authenticated.";

    final res = await http.post(
      Uri.parse("$backendUrl/start_story"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({
        "decision"    : decision,
        "dimensions"  : dimensionData,
        "maxLegs"     : maxLegs,
        "optionCount" : optionCount,
        "storyLength" : storyLength,
      }),
    );

    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      return {
        "storyLeg"  : d["aiResponse"]["storyLeg"]  ?? "No story leg returned.",
        "options"   : d["aiResponse"]["options"]   ?? [],
        "storyTitle": d["aiResponse"]["storyTitle"]?? "Untitled Story",
      };
    }
    throw jsonDecode(res.body)["message"] ?? res.body;
  }

  Future<Map<String, dynamic>> getNextLeg({required String decision}) async {
    final token = await authService.getToken();
    if (token == null) throw "User is not authenticated.";

    final res = await http.post(
      Uri.parse("$backendUrl/next_leg"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({"decision": decision}),
    );

    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      return {
        "storyLeg"  : d["aiResponse"]["storyLeg"]  ?? "No story leg returned.",
        "options"   : d["aiResponse"]["options"]   ?? [],
        "storyTitle": d["aiResponse"]["storyTitle"]?? "Untitled Story",
      };
    }
    throw jsonDecode(res.body)["message"] ?? res.body;
  }

  Future<Map<String, dynamic>> saveStory({String? sessionId}) async {
    final token = await authService.getToken();
    if (token == null) throw 'User is not authenticated.';

    final qs  = sessionId == null ? '' : '?sessionId=$sessionId';
    final res = await http.post(
      Uri.parse('$backendUrl/save_story$qs'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type' : 'application/json',
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw jsonDecode(res.body)['message'] ?? res.body;
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

  Future<Map<String, dynamic>> getFullStory({String? sessionId}) async {
    final token = await authService.getToken();
    if (token == null) throw 'User is not authenticated.';

    final qs  = sessionId == null ? '' : '?sessionId=$sessionId';
    final res = await http.get(
      Uri.parse('$backendUrl/story$qs'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type' : 'application/json',
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw jsonDecode(res.body)['message'] ?? res.body;
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

/*───────────────────────  M U L T I P L A Y E R  ──────────────────────────*/

  /// 1️⃣ Host reserves a sessionId + joinCode.
  Future<Map<String, dynamic>> createMultiplayerSession() async {
    final token = await authService.getToken();
    if (token == null) throw "User is not authenticated.";

    final res = await http.post(
      Uri.parse("$backendUrl/create_multiplayer_session"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
    );

    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      return {
        "sessionId": d["sessionId"],
        "joinCode" : d["joinCode"],
      };
    }
    throw jsonDecode(res.body)["message"] ?? res.body;
  }

  /// 2️⃣ Joiner validates a join‑code, gets the sessionId back.
  Future<Map<String, dynamic>> joinMultiplayerSession({
    required String joinCode,
    required String displayName,
  }) async {
    final token = await authService.getToken();
    if (token == null) throw "User is not authenticated.";

    final res = await http.post(
      Uri.parse("$backendUrl/join_multiplayer_session"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({"joinCode": joinCode, "displayName": displayName}),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw jsonDecode(res.body)["message"] ?? res.body;
  }

  /// 3️⃣ Host calls this *after* votes resolved to get first story leg.
  Future<Map<String, dynamic>> startStoryForMultiplayer({
    required Map<String, dynamic> resolvedDimensions,
    required int maxLegs,
    required int optionCount,
    required String storyLength,
  }) async {
    return startStory(
      decision      : "Start Story",
      dimensionData : resolvedDimensions,
      maxLegs       : maxLegs,
      optionCount   : optionCount,
      storyLength   : storyLength,
    );
  }




}