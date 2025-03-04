import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';
import 'login_screen.dart';

class StoryScreen extends StatefulWidget {
  final String? initialLeg;

  const StoryScreen({Key? key, this.initialLeg}) : super(key: key);

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final AuthService authService = AuthService();
  final StoryService storyService = StoryService();
  final TextEditingController textController = TextEditingController();
  final List<String> menuItems = [
    "First Option",
    "Second Option",
  ];

  @override
  void initState() {
    super.initState();
    // Display the initial story leg if provided.
    if (widget.initialLeg != null) {
      textController.text = widget.initialLeg!;
    }
  }

  void logout(BuildContext context) async {
    await authService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void onMenuItemSelected(String item) {
    setState(() {
      textController.text += "\n$item selected\n";
    });
    // When a decision is made, call getNextLeg with that decision.
    getNextStoryLeg(item);
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

  // Calls getNextLeg from StoryService and updates the displayed story.
  Future<void> getNextStoryLeg(String decision) async {
    try {
      final newLeg = await storyService.getNextLeg(decision: decision);
      setState(() {
        textController.text += "\nNew story leg: $newLeg\n";
      });
    } catch (e) {
      setState(() {
        textController.text += "\nError calling backend: $e\n";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Story"),
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
                      readOnly: true,
                      decoration: InputDecoration.collapsed(
                        hintText: "Story will appear here...",
                      ),
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
