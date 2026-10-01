import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'identity_context.dart';

final identityContextProvider = Provider<IdentityContext>(
  (ref) => throw StateError('IdentityContext must be overridden.'),
);
