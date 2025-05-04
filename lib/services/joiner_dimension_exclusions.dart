/// Dimensions that **joiners** should never vote on.
/// (Hosts may still set these, so they stay visible in the host UI.)
///
/// This works exactly like `dimension_exclusions.dart`, but applies
/// **only** when a player is joining an existing multiplayer session.
library joiner_dimension_exclusions;

import 'dimension_exclusions.dart';

/// All exclusions that already apply to everyone …
const List<String> joinerExcludedDimensions = [
  ...excludedDimensions,

  // … plus the dimensions that only the host may decide:
  'Minimum Number of Options',
  'Story Length',
];
