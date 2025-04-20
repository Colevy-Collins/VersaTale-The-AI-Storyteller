// lib/models/story_phase.dart

/// The different RTDB phases for our story flow.
enum StoryPhase { story, vote, results, lobby }

extension StoryPhaseParsing on StoryPhase {
  /// Parse the string coming from RTDB into our enum.
  static StoryPhase fromString(String s) {
    switch (s) {
      case 'storyVote':
        return StoryPhase.vote;
      case 'storyVoteResults':
        return StoryPhase.results;
      case 'lobby':
        return StoryPhase.lobby;
      case 'story':
      default:
        return StoryPhase.story;
    }
  }

  /// Convert our enum back into the exact string RTDB expects.
  String get asString {
    switch (this) {
      case StoryPhase.vote:
        return 'storyVote';
      case StoryPhase.results:
        return 'storyVoteResults';
      case StoryPhase.lobby:
        return 'lobby';
      case StoryPhase.story:
      default:
        return 'story';
    }
  }
}
