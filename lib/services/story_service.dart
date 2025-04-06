import 'dart:convert';
import 'dart:io'; // Needed to catch SocketException.
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StoryService {
  // Replace with your actual backend URL.
  final String backendUrl = "https://cloud-run-backend-706116508486.us-central1.run.app"; //"http://localhost:8080";
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
      } else {
        throw "An error occurred: $e";
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
      } else {
        throw "An error occurred: $e";
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
      } else {
        throw "An error occurred: $e";
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
      } else {
        throw "An error occurred: $e";
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
      } else {
        throw "An error occurred: $e";
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
      } else {
        throw "An error occurred: $e";
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
      } else {
        throw "An error occurred: $e";
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
      } else {
        throw "An error occurred: $e";
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
      } else {
        throw "An error occurred: $e";
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
      } else {
        throw "An error occurred: $e";
      }
    }
  }
}
