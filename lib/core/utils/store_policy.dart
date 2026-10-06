import 'package:flutter/foundation.dart';

/// App Store builds must not send users to sign-up, pricing or subscription
/// pages outside the app (App Review Guideline 3.1.1). CLOUDPOS is sold to
/// businesses outside the app, so on iOS/iPadOS every such link is hidden and
/// users are told to contact their administrator instead. Android, Windows and
/// web keep the links.
bool get hideExternalCommerceLinks =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
