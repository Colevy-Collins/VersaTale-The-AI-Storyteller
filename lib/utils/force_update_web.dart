import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Forces a single hard‑refresh when a newer service‑worker is available.
///No‑op on mobile/desktop builds.
class ForceUpdateWeb {
  ForceUpdateWeb._();
  static bool _ran = false;

  static Future<void> runOnce() async {
    if (_ran || !kIsWeb) return;
    _ran = true;

    final swContainer = html.window.navigator.serviceWorker;
    if (swContainer == null) return;          // browser has no SW support

    final reg = await swContainer.getRegistration();
    if (reg == null) return;                 // first visit – nothing to update

    await reg.update();                      // ask the browser to check NOW

    // ------------------------------------------------------------------
    // 1.  A new service‑worker file was found and is installing…
    // ------------------------------------------------------------------
    reg.addEventListener('updatefound', (html.Event _) {
      final fresh = reg.installing;
      if (fresh == null) return;

      // 2.  Track the install state of the NEW worker
      fresh.addEventListener('statechange', (html.Event _) {
        final ready  = fresh.state == 'installed';
        final hasOld = swContainer.controller != null;
        if (ready && hasOld) {
          // 3.  Tell the NEW worker to activate immediately
          fresh.postMessage('skipWaiting');  // stock Flutter SW understands this
        }
      });
    });

    // ------------------------------------------------------------------
    // 4.  When the NEW worker takes control → hard‑refresh ONCE
    // ------------------------------------------------------------------
    swContainer.addEventListener('controllerchange', (html.Event _) {
      html.window.location.reload();         // bypass cache, pick up fresh build
    });
  }
}
