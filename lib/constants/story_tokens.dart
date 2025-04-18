/// Shared vote/command tokens used across the multiplayer code.
///
/// Having them in one file avoids “undefined‑name” and keeps every
/// reference identical.
library story_tokens;

/// Special value for a vote that means “go back to the previous leg”.
const String kPreviousLegToken = '<<PREVIOUS_LEG>>';
