import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService authService = AuthService();
  final TextEditingController textController = TextEditingController();
  final List<String> menuItems = [
    "First Option",
    "Second Option",
  ];

  // Replace with your Cloud Run backend URL.
  final String backendUrl = "https://cloud-run-backend-706116508486.us-central1.run.app";

  void logout(BuildContext context) async {
    await authService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void onMenuItemSelected(String item) {
    setState(() {
      textController.text += "$item selected\n";
    });

    // Call the backend with the selected decision.
    callBackend(item);
  }

  void showButtonMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 250,
          child: Scrollbar(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: ElevatedButton(
                    onPressed: () {
                      onMenuItemSelected(menuItems[index]);
                      Navigator.pop(context); // Close menu
                    },
                    child: Text(menuItems[index]),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Function to call the backend and send the decision
  Future<void> callBackend(String decision) async {
    try {
      // Retrieve a fresh Firebase ID token.
      final token = await authService.getToken();
      if (token == null) {
        setState(() {
          textController.text += "Error: User is not authenticated.\n";
        });
        return;
      }

      // Build the URL for your backend endpoint.
      final url = Uri.parse(backendUrl + "/story");

      // Make an authenticated POST request.
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'decision': decision}),
      );

      if (response.statusCode == 200) {
        // Parse the response and update the story.
        final responseData = jsonDecode(response.body);
        setState(() {
          textController.text += "New story leg: ${responseData['newLeg']}\n";
        });
      } else {
        setState(() {
          textController.text += "Backend error: ${response.statusCode}\n";
        });
      }
    } catch (e) {
      setState(() {
        textController.text += "Error calling backend: $e\n";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => logout(context),
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: TextField(
                      controller: textController,
                      maxLines: null,
                      decoration: InputDecoration.collapsed(
                          hintText: "Text will appear here..."),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => showButtonMenu(context),
              child: Text("Open Menu"),
            ),
          ],
        ),
      ),
    );
  }
}
