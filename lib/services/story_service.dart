// lib/services/story_service.dart
// -----------------------------------------------------------------------------
// Wraps all HTTP calls, translates backend / network / HTTP errors into
// actionable, user‑friendly messages, and exposes a high‑level API for the UI.
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Thrown whenever an API call fails (or user isn’t signed‑in).
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class StoryService {
  final String backendUrl = "http://localhost:8080";//'https://cloud-run-backend-706116508486.us-central1.run.app';
  final AuthService authService = AuthService();

  // ──────────────────────────────────────────────────────────────
  // 1) Raw backend “message” strings (keep in sync with controllers)
  // ──────────────────────────────────────────────────────────────
  static const _missingDimensionOption =
      'One or more required dimension options are missing.';
  static const _maxUserStoriesReached =
      'User has reached the maximum number of saved stories.';
  static const _cannotRemoveLastStoryLeg =
      'Cannot remove the last story leg because only one leg remains.';
  static const _incompatibleStoryVersion =
      'Your saved story isn’t compatible with the current version of the app and can not be continued. Please create a new story.';

  // Multiplayer / lobby
  static const _missingJoinCode          = 'Missing joinCode';          // :contentReference[oaicite:0]{index=0}:contentReference[oaicite:1]{index=1}
  static const _invalidOrExpiredJoinCode = 'Invalid or expired join code'; // :contentReference[oaicite:2]{index=2}:contentReference[oaicite:3]{index=3}
  static const _sessionNotFound          = 'Session not found';         // :contentReference[oaicite:4]{index=4}:contentReference[oaicite:5]{index=5}

  // Story continuation
  static const _missingDecision          = 'Missing decision';          // :contentReference[oaicite:6]{index=6}:contentReference[oaicite:7]{index=7}
  static const _storyOptionsNotSet       = 'Story options not set.';    // :contentReference[oaicite:8]{index=8}:contentReference[oaicite:9]{index=9}

  // ──────────────────────────────────────────────────────────────
  // 2) Polished wording for the UI
  // ──────────────────────────────────────────────────────────────
  static const Map<String, String> _friendly = {
    _missingDimensionOption   : _missingDimensionOption,
    _maxUserStoriesReached    : _maxUserStoriesReached,
    _cannotRemoveLastStoryLeg : _cannotRemoveLastStoryLeg,
    _incompatibleStoryVersion : _incompatibleStoryVersion,

    _missingJoinCode          : 'Please enter a join code.',
    _invalidOrExpiredJoinCode : 'That join code is invalid or has expired.',
    _sessionNotFound          : 'The multiplayer session could not be found.',
    _missingDecision          : 'Choose an option to continue the story.',
    _storyOptionsNotSet       : 'Story setup incomplete. Please pick all dimension options first.',
  };

  // ──────────────────────────────────────────────────────────────
  // 3) Best‑message selector
  // ──────────────────────────────────────────────────────────────
  String _getFriendlyErrorMessage({
    int? statusCode,
    dynamic exception,
    String? serverMessage,
  }) {
    // ① exact string from backend
    if (serverMessage != null) {
      final mapped = _friendly[serverMessage];
      if (mapped != null) return mapped;
    }

    // ② network / client exceptions
    if (exception != null) {
      if (exception is SocketException) {
        return 'Network error: unable to reach the server. '
            'Please check your internet connection.';
      }
      if (exception is http.ClientException) {
        return 'Network error: unable to reach the server. '
            '(${exception.message})';
      }
      return 'Unexpected error: ${exception.toString()}';
    }

    // ③ common HTTP codes
    if (statusCode != null) {
      switch (statusCode) {
        case 400: return 'Bad request. Please verify your inputs.';
        case 401: return 'Authentication failed. Please sign in again.';
        case 403: return 'You do not have permission to perform this action.';
        case 404: return 'Requested resource not found.';
        case 500: return 'Server error. Please try again later.';
      }
    }

    // ④ fallback
    if (serverMessage != null && serverMessage.isNotEmpty) return serverMessage;
    return 'An unknown error occurred.';
  }

  // ──────────────────────────────────────────────────────────────
  // 4) Shared HTTP helper
  // ──────────────────────────────────────────────────────────────
  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final token = await authService.getToken();
    if (token == null) throw ApiException('User is not authenticated.');

    final uri = Uri.parse('$backendUrl/$path')
        .replace(queryParameters: queryParams);

    http.Response res;
    try {
      if (method == 'POST') {
        res = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type' : 'application/json',
          },
          body: body != null ? jsonEncode(body) : null,
        );
      } else {
        res = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type' : 'application/json',
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

    // pull out server “message” if present
    String serverMsg = '';
    try {
      final decoded = jsonDecode(res.body);
      serverMsg = (decoded is Map && decoded['message'] != null)
          ? decoded['message']
          : res.body;
    } catch (_) {
      serverMsg = res.body;
    }

    throw ApiException(_getFriendlyErrorMessage(
      statusCode   : res.statusCode,
      serverMessage: serverMsg,
    ));
  }

  // ──────────────────────────────────────────────────────────────
  // 5) Data shaper used by several endpoints
  // ──────────────────────────────────────────────────────────────
  Map<String, dynamic> _storySlice(
      Map<String, dynamic> src, {
        bool nested = false,
      }) {
    final target = nested ? (src['aiResponse'] as Map? ?? {}) : src;
    return {
      'storyLeg'        : target['storyLeg']        ?? src['initialLeg']     ?? 'No story leg returned.',
      'options'         : target['options']         ?? src['options']        ?? [],
      'storyTitle'      : target['storyTitle']      ?? src['storyTitle']     ?? 'Untitled Story',
      'inputTokens'     : target['inputTokens']     ?? src['inputTokens']    ?? 0,
      'outputTokens'    : target['outputTokens']    ?? src['outputTokens']   ?? 0,
      'estimatedCostUsd': target['estimatedCostUsd']?? src['estimatedCostUsd']?? 0.0,
    };
  }

  // ──────────────────────────────────────────────────────────────
  // 6) PUBLIC API – Solo play
  // ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> startStory({
    required String decision,
    required Map<String, dynamic> dimensionData,
    required int maxLegs,
    required int optionCount,
    required String storyLength,
  }) async {
    final d = await _request(
      method: 'POST',
      path  : 'start_story',
      body  : {
        'decision'   : decision,
        'dimensions' : dimensionData,
        'maxLegs'    : maxLegs,
        'optionCount': optionCount,
        'storyLength': storyLength,
      },
    );
    return _storySlice(d, nested: true);
  }

  Future<Map<String, dynamic>> getNextLeg({required String decision}) async {
    final d = await _request(
      method: 'POST',
      path  : 'next_leg',
      body  : {'decision': decision},
    );
    return _storySlice(d, nested: true);
  }

  Future<Map<String, dynamic>> getPreviousLeg() async {
    final d = await _request(method: 'GET', path: 'previous_leg');
    return _storySlice(d, nested: true);
  }

  Future<Map<String, dynamic>> continueStory({required String storyId}) async {
    final d = await _request(
      method: 'POST',
      path  : 'continue_story',
      body  : {'storyId': storyId},
    );
    return _storySlice(d);
  }

  Future<Map<String, dynamic>?> getActiveStory() async {
    final d = await _request(method: 'GET', path: 'story');
    return _storySlice(d);
  }

  Future<Map<String, dynamic>> getFullStory({String? sessionId}) =>
      _request(
        method: 'GET',
        path  : 'story',
        queryParams: sessionId != null ? {'sessionId': sessionId} : null,
      ).then((v) => v as Map<String, dynamic>);

  Future<Map<String, dynamic>> saveStory({String? sessionId}) =>
      _request(
        method: 'POST',
        path  : 'save_story',
        queryParams: sessionId != null ? {'sessionId': sessionId} : null,
      ).then((v) => v as Map<String, dynamic>);

  Future<List<dynamic>> getSavedStories() async {
    final d = await _request(method: 'GET', path: 'saved_stories');
    return (d as Map<String, dynamic>)['stories'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> viewStory({required String storyId}) =>
      _request(
        method: 'GET',
        path  : 'view_story',
        queryParams: {'storyId': storyId},
      ).then((v) => v as Map<String, dynamic>);

  Future<bool> deleteStory({required String storyId}) async {
    await _request(
      method: 'POST',
      path  : 'delete_story',
      body  : {'storyId': storyId},
    );
    return true;
  }

  Future<bool> deleteAllStories() async {
    await _request(method: 'POST', path: 'delete_all_stories');
    return true;
  }

  // ──────────────────────────────────────────────────────────────
  // 7) PUBLIC API – User profile & prefs
  // ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getUserProfile() =>
      _request(method: 'GET', path: 'profile')
          .then((v) => v as Map<String, dynamic>);

  Future<void> updateUserTheme({
    required String paletteKey,
    required String fontFamily,
  }) async {
    await _request(
      method: 'POST',
      path  : 'update_user_theme',
      body  : {'preferredPalette': paletteKey, 'preferredFont': fontFamily},
    );
  }

  Future<void> updateLastAccessDate() async =>
      _request(method: 'POST', path: 'update_last_access');

  Future<void> deleteUserData() async =>
      _request(method: 'POST', path: 'delete_user_data');

  // ──────────────────────────────────────────────────────────────
  // 8) PUBLIC API – Multiplayer
  // ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createMultiplayerSession(String isNewGame) =>
      _request(
        method: 'POST',
        path  : 'create_multiplayer_session',
        body  : {'isNewGame': isNewGame},
      ).then((v) => v as Map<String, dynamic>);

  Future<Map<String, dynamic>> joinMultiplayerSession({
    required String joinCode,
    required String displayName,
  }) =>
      _request(
        method: 'POST',
        path  : 'join_multiplayer_session',
        body  : {'joinCode': joinCode, 'displayName': displayName},
      ).then((v) => v as Map<String, dynamic>);

  Future<Map<String, dynamic>> startStoryForMultiplayer({
    required Map<String, dynamic> resolvedDimensions,
    required int maxLegs,
    required int optionCount,
    required String storyLength,
  }) =>
      startStory(
        decision     : 'Start Story',
        dimensionData: resolvedDimensions,
        maxLegs      : maxLegs,
        optionCount  : optionCount,
        storyLength  : storyLength,
      );
}
