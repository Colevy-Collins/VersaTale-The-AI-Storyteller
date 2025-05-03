import 'dart:math';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';
import 'register_screen.dart';
import '../../utils/ui_utils.dart';

/// Splash / landing page that forces a check for a newer build,
/// and reloads the tab exactly once when the service-worker updates.
class MainSplashScreen extends StatefulWidget {
  const MainSplashScreen({Key? key}) : super(key: key);

  @override
  State<MainSplashScreen> createState() => _MainSplashScreenState();
}

class _MainSplashScreenState extends State<MainSplashScreen> {
  bool _hasReloaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _checkForNewBuild();
  }

  Future<void> _checkForNewBuild() async {
    // 1️⃣ Grab the ServiceWorkerContainer; bail if unsupported
    final swContainer = html.window.navigator.serviceWorker;
    if (swContainer == null) return;

    // 2️⃣ Get the current registration (null on very first visit)
    final reg = await swContainer.getRegistration();
    if (reg == null) return;

    // 3️⃣ Force an immediate network update check
    await reg.update();

    // 4️⃣ Listen for the 'updatefound' event on the registration
    reg.addEventListener('updatefound', (html.Event _) {
      final sw = reg.installing;
      if (sw == null) return;

      // 5️⃣ When the new worker reaches 'installed' and an old one controls the page,
      //    send it SKIP_WAITING so it activates immediately.
      sw.addEventListener('statechange', (html.Event __) {
        final installed = sw.state == 'installed';
        final hasOldController = html.window.navigator.serviceWorker?.controller != null;
        if (installed && hasOldController) {
          sw.postMessage({'type': 'SKIP_WAITING'});
        }
      });
    });

    // 6️⃣ When the new worker takes control, reload the page exactly once
    swContainer.addEventListener('controllerchange', (html.Event _) {
      if (_hasReloaded) return;
      _hasReloaded = true;
      html.window.location.reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/versatale_home_image.png',
                fit: BoxFit.cover,
              ),
            ),
            LayoutBuilder(builder: (context, constraints) {
              final buttonWidth = constraints.maxWidth * 0.6;
              final fontSize = min(constraints.maxWidth * 0.05, 28.0);
              return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.2),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          ),
                          child: Text(
                            'Login',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: buttonWidth,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.2),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          ),
                          child: Text(
                            "Don't have an account? Sign Up",
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 1,
                        width: buttonWidth * 0.8,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: constraints.maxWidth * 0.5,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => openTutorialPdf(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book,
                                  color: Colors.white, size: fontSize * 0.8),
                              const SizedBox(width: 8),
                              Text(
                                'Tutorial',
                                style: TextStyle(
                                  fontSize: fontSize * 0.8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
