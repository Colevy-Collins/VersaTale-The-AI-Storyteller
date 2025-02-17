import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService authService = AuthService();
  final TextEditingController textController = TextEditingController();
  final List<String> menuItems = [
    "Action 1",
    "Action 2",
    "Action 3",
    "Action 4"
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
                  title: Text(menuItems[index]),
                  onTap: () {
                    onMenuItemSelected(menuItems[index]);
                    Navigator.pop(context); // Close menu
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // New function to call the backend
  Future<void> callBackend() async {
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
      final url = Uri.parse(backendUrl);

      // Make an authenticated GET request.
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          textController.text += "Backend response: ${response.body}\n";
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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: callBackend,
              child: Text("Call Backend"),
            ),
          ],
        ),
      ),
    );
  }
}
