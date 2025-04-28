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
  final String backendUrl =
      "http://localhost:8080"; // or your Cloud Run URL
  final AuthService authService = AuthService();

  // -------------------------------------------------------------------------
  // Known server messages → friendlier wording
  // -------------------------------------------------------------------------
  static const _missingDimensionOption =
      'One or more required dimension options are missing.';
  static const _maxUserStoriesReached =
      'User has reached the maximum number of saved stories.';
  static const _cannotRemoveLastStoryLeg =
      'Cannot remove the last story leg because only one leg remains.';

  String _getFriendlyErrorMessage({
    int? statusCode,
    dynamic exception,
    String? serverMessage,
  }) {
    if (serverMessage != null) {
      if (serverMessage == _missingDimensionOption ||
          serverMessage == _maxUserStoriesReached ||
          serverMessage == _cannotRemoveLastStoryLeg) {
        return serverMessage;
      }
    }

    if (exception != null) {
      if (exception is SocketException) {
        return 'Network error: unable to reach server. Please check your internet connection.';
      }
      if (exception is http.ClientException) {
        return 'Network error: unable to reach server. (${exception.message})';
      }
      return 'Unexpected error: ${exception.toString()}';
    }

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

    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }

    return 'An unknown error occurred.';
  }

  // -------------------------------------------------------------------------
  // Shared HTTP helper
  // -------------------------------------------------------------------------
  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final token = await authService.getToken();
    if (token == null) throw ApiException('User is not authenticated.');

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

    if (res.statusCode == 200) return jsonDecode(res.body);

    String serverMsg = '';
    try {
      final decoded = jsonDecode(res.body);
      serverMsg =
      decoded is Map && decoded['message'] != null ? decoded['message'] : res.body;
    } catch (_) {
      serverMsg = res.body;
    }

    throw ApiException(_getFriendlyErrorMessage(
      statusCode: res.statusCode,
      serverMessage: serverMsg,
    ));
  }

  // ───────────────────────── SOLO + STORY ──────────────────────────
  // Every helper below now extracts token + cost numbers.

  Map<String, dynamic> _storySlice(Map<String, dynamic> src,
      {bool nested = false}) {
    // If the values live inside aiResponse (nested = true) look there first.
    final target = nested ? (src['aiResponse'] as Map? ?? {}) : src;
    return {
      'storyLeg'        : target['storyLeg'] ?? src['initialLeg'] ?? 'No story leg returned.',
      'options'         : target['options']  ?? src['options']    ?? [],
      'storyTitle'      : target['storyTitle'] ?? src['storyTitle'] ?? 'Untitled Story',
      'inputTokens'     : target['inputTokens']     ?? src['inputTokens']     ?? 0,
      'outputTokens'    : target['outputTokens']    ?? src['outputTokens']    ?? 0,
      'estimatedCostUsd': target['estimatedCostUsd']?? src['estimatedCostUsd']?? 0.0,
    };
  }

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
    return _storySlice(d, nested: true);
  }

  Future<Map<String, dynamic>> getNextLeg({required String decision}) async {
    final d = await _request(
      method: 'POST',
      path: 'next_leg',
      body: {'decision': decision},
    );
    return _storySlice(d, nested: true);
  }

  Future<Map<String, dynamic>> saveStory({String? sessionId}) =>
      _request(
        method: 'POST',
        path: 'save_story',
        queryParams: sessionId != null ? {'sessionId': sessionId} : null,
      ).then((v) => v as Map<String, dynamic>);

  Future<List<dynamic>> getSavedStories() async {
    final d = await _request(method: 'GET', path: 'saved_stories');
    return (d as Map<String, dynamic>)['stories'] as List<dynamic>;
  }

  Future<Map<String, dynamic>?> getActiveStory() async {
    final d = await _request(method: 'GET', path: 'story');
    return _storySlice(d);
  }

  Future<Map<String, dynamic>> viewStory({required String storyId}) =>
      _request(
        method: 'GET',
        path: 'view_story',
        queryParams: {'storyId': storyId},
      ).then((v) => v as Map<String, dynamic>);

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
    return _storySlice(d);
  }

  Future<Map<String, dynamic>> getPreviousLeg() async {
    final d = await _request(method: 'GET', path: 'previous_leg');
    return _storySlice(d, nested: true);
  }

  Future<Map<String, dynamic>> getFullStory({String? sessionId}) =>
      _request(
        method: 'GET',
        path: 'story',
        queryParams: sessionId != null ? {'sessionId': sessionId} : null,
      ).then((v) => v as Map<String, dynamic>);

  // ─────────────────────── USER PROFILE / PREFERENCES ─────────────────────
  Future<Map<String, dynamic>> getUserProfile() =>
      _request(method: 'GET', path: 'profile')
          .then((v) => v as Map<String, dynamic>);

  Future<void> updateUserTheme({
    required String paletteKey,
    required String fontFamily,
  }) async {
    await _request(
      method: 'POST',
      path: 'update_user_theme',
      body: {'preferredPalette': paletteKey, 'preferredFont': fontFamily},
    );
  }

  Future<void> deleteUserData() async =>
      _request(method: 'POST', path: 'delete_user_data');

  Future<bool> deleteAllStories() async {
    await _request(method: 'POST', path: 'delete_all_stories');
    return true;
  }

  Future<void> updateLastAccessDate() async =>
      _request(method: 'POST', path: 'update_last_access');

  // ────────────────────────── MULTIPLAYER ──────────────────────────
  Future<Map<String, dynamic>> createMultiplayerSession(String isNewGame) =>
      _request(
        method: 'POST',
        path: 'create_multiplayer_session',
        body: {'isNewGame': isNewGame},
      ).then((v) => v as Map<String, dynamic>);

  Future<Map<String, dynamic>> joinMultiplayerSession({
    required String joinCode,
    required String displayName,
  }) =>
      _request(
        method: 'POST',
        path: 'join_multiplayer_session',
        body: {'joinCode': joinCode, 'displayName': displayName},
      ).then((v) => v as Map<String, dynamic>);

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