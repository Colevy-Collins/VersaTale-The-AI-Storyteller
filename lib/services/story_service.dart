import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Thrown whenever an API call fails or the user isn't authenticated.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class StoryService {
  final String backendUrl = "http://localhost:8080"; //"https://cloud-run-backend-706116508486.us-central1.run.app/"; //"http://localhost:8080";;
  final AuthService authService = AuthService();

  /// These match exactly what your server might send in { "message": "…" }.
  static const _missingDimensionOption =
      'One or more required dimension options are missing.';
  static const _maxUserStoriesReached =
      'User has reached the maximum number of saved stories.';
  static const _cannotRemoveLastStoryLeg =
      'Cannot remove the last story leg because only one leg remains.';

  /// Maps HTTP status codes and common network exceptions
  /// (or backend‑returned messages) to user‑friendly text.
  String _getFriendlyErrorMessage({
    int? statusCode,
    dynamic exception,
    String? serverMessage,
  }) {
    // 1) If the server literally returned one of our known messages, show it directly:
    if (serverMessage != null) {
      if (serverMessage == _missingDimensionOption ||
          serverMessage == _maxUserStoriesReached ||
          serverMessage == _cannotRemoveLastStoryLeg) {
        return serverMessage;
      }
    }

    // 2) Network / client exceptions
    if (exception != null) {
      if (exception is SocketException) {
        return 'Network error: unable to reach server. Please check your internet connection.';
      }
      if (exception is http.ClientException) {
        return 'Network error: unable to reach server. (${exception.message})';
      }
      return 'Unexpected error: ${exception.toString()}';
    }

    // 3) HTTP status code mappings
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'Bad request. Please verify your inputs.';
        case 401:
          return 'Authentication failed. Please sign in again.';
        case 403:
          return 'You do not have permission to perform this action.';
        case 404:
          return 'Requested resource not found.';
        case 500:
          return 'Server error. Please try again later.';
      }
    }

    // 4) Finally, if we have any other serverMessage, show that
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }

    // Ultimate fallback
    return 'An unknown error occurred.';
  }

  /// Internal helper that handles GET/POST, JSON encoding/decoding,
  /// auth header, query params, and error‐handling.
  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final token = await authService.getToken();
    if (token == null) {
      throw ApiException('User is not authenticated.');
    }

    final uri =
    Uri.parse('$backendUrl/$path').replace(queryParameters: queryParams);
    http.Response res;

    try {
      if (method == 'POST') {
        res = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body != null ? jsonEncode(body) : null,
        );
      } else {
        res = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      }
    } on SocketException catch (e) {
      throw ApiException(_getFriendlyErrorMessage(exception: e));
    } catch (e) {
      if (e is http.ClientException) {
        throw ApiException(_getFriendlyErrorMessage(exception: e));
      }
      throw ApiException(_getFriendlyErrorMessage(exception: e));
    }

    // 200 OK → parse JSON
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    // Extract server-sent message, if any
    String serverMsg = '';
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['message'] != null) {
        serverMsg = decoded['message'];
      } else {
        serverMsg = res.body;
      }
    } catch (_) {
      serverMsg = res.body;
    }

    // Build the friendly message in order of priority
    final friendly = _getFriendlyErrorMessage(
      statusCode: res.statusCode,
      serverMessage: serverMsg,
    );
    throw ApiException(friendly);
  }

  // ───────────────────────── SOLO + STORY ──────────────────────────

  Future<Map<String, dynamic>> startStory({
    required String decision,
    required Map<String, dynamic> dimensionData,
    required int maxLegs,
    required int optionCount,
    required String storyLength,
  }) async {
    final d = await _request(
      method: 'POST',
      path: 'start_story',
      body: {
        'decision': decision,
        'dimensions': dimensionData,
        'maxLegs': maxLegs,
        'optionCount': optionCount,
        'storyLength': storyLength,
      },
    );
    final ai = d['aiResponse'] as Map<String, dynamic>? ?? {};
    return {
      'storyLeg': ai['storyLeg'] ?? 'No story leg returned.',
      'options': ai['options'] ?? [],
      'storyTitle': ai['storyTitle'] ?? 'Untitled Story',
    };
  }

  Future<Map<String, dynamic>> getNextLeg({required String decision}) async {
    final d = await _request(
      method: 'POST',
      path: 'next_leg',
      body: {'decision': decision},
    );
    final ai = d['aiResponse'] as Map<String, dynamic>? ?? {};
    return {
      'storyLeg': ai['storyLeg'] ?? 'No story leg returned.',
      'options': ai['options'] ?? [],
      'storyTitle': ai['storyTitle'] ?? 'Untitled Story',
    };
  }

  Future<Map<String, dynamic>> saveStory({String? sessionId}) async {
    return await _request(
      method: 'POST',
      path: 'save_story',
      queryParams: sessionId != null ? {'sessionId': sessionId} : null,
    ) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getSavedStories() async {
    final d = await _request(method: 'GET', path: 'saved_stories');
    return (d as Map<String, dynamic>)['stories'] as List<dynamic>;
  }

  Future<Map<String, dynamic>?> getActiveStory() async {
    final d = await _request(method: 'GET', path: 'story');
    return {
      'storyLeg':
      (d as Map<String, dynamic>)['initialLeg'] ?? 'No story leg returned.',
      'options': d['options'] ?? [],
      'storyTitle': d['storyTitle'] ?? 'Untitled Story',
    };
  }

  Future<Map<String, dynamic>> viewStory({required String storyId}) async {
    return await _request(
      method: 'GET',
      path: 'view_story',
      queryParams: {'storyId': storyId},
    ) as Map<String, dynamic>;
  }

  Future<bool> deleteStory({required String storyId}) async {
    await _request(
      method: 'POST',
      path: 'delete_story',
      body: {'storyId': storyId},
    );
    return true;
  }

  Future<Map<String, dynamic>> continueStory({required String storyId}) async {
    final d = await _request(
      method: 'POST',
      path: 'continue_story',
      body: {'storyId': storyId},
    );
    final ai = d as Map<String, dynamic>;
    return {
      'storyLeg': ai['initialLeg'] ?? 'No story leg returned.',
      'options': ai['options'] ?? [],
      'storyTitle': ai['storyTitle'] ?? 'Untitled Story',
    };
  }

  Future<Map<String, dynamic>> getPreviousLeg() async {
    final d = await _request(method: 'GET', path: 'previous_leg');
    final ai =
        (d as Map<String, dynamic>)['aiResponse'] as Map<String, dynamic>? ??
            {};
    return {
      'storyLeg': ai['storyLeg'] ?? 'No story leg returned.',
      'options': ai['options'] ?? [],
      'storyTitle': ai['storyTitle'] ?? 'Untitled Story',
    };
  }

  Future<Map<String, dynamic>> getFullStory({String? sessionId}) async {
    return await _request(
      method: 'GET',
      path: 'story',
      queryParams: sessionId != null ? {'sessionId': sessionId} : null,
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    return await _request(method: 'GET', path: 'profile') as Map<String, dynamic>;
  }

  Future<void> deleteUserData() async {
    await _request(method: 'POST', path: 'delete_user_data');
  }

  Future<bool> deleteAllStories() async {
    await _request(method: 'POST', path: 'delete_all_stories');
    return true;
  }

  Future<void> updateLastAccessDate() async {
    await _request(method: 'POST', path: 'update_last_access');
  }

  // ─────────────────────── MULTIPLAYER ──────────────────────────

  Future<Map<String, dynamic>> createMultiplayerSession(
      String isNewGame) async =>
      await _request(
        method: 'POST',
        path: 'create_multiplayer_session',
        body: {'isNewGame': isNewGame},
      ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> joinMultiplayerSession({
    required String joinCode,
    required String displayName,
  }) async =>
      await _request(
        method: 'POST',
        path: 'join_multiplayer_session',
        body: {'joinCode': joinCode, 'displayName': displayName},
      ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> startStoryForMultiplayer({
    required Map<String, dynamic> resolvedDimensions,
    required int maxLegs,
    required int optionCount,
    required String storyLength,
  }) =>
      startStory(
        decision: 'Start Story',
        dimensionData: resolvedDimensions,
        maxLegs: maxLegs,
        optionCount: optionCount,
        storyLength: storyLength,
      );
}
