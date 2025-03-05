import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';
import 'login_screen.dart';

class StoryScreen extends StatefulWidget {
  final String? initialLeg;
  final List<String> options; // Initial options returned by the backend.

  const StoryScreen({Key? key, this.initialLeg, required this.options}) : super(key: key);

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final AuthService authService = AuthService();
  final StoryService storyService = StoryService();
  final TextEditingController textController = TextEditingController();

  // Current options provided by the AI.
  late List<String> currentOptions;

  @override
  void initState() {
    super.initState();
    if (widget.initialLeg != null) {
      textController.text = widget.initialLeg!;
    }
    currentOptions = widget.options;
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
    // Call backend to get the next story leg using the selected decision.
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
              itemCount: currentOptions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: ElevatedButton(
                    onPressed: () {
                      onMenuItemSelected(currentOptions[index]);
                      Navigator.pop(context); // Close menu
                    },
                    child: Text(currentOptions[index]),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Calls getNextLeg from StoryService and updates both the story leg and the current options.
  Future<void> getNextStoryLeg(String decision) async {
    try {
      final response = await storyService.getNextLeg(decision: decision);
      setState(() {
        textController.text += "\nNew story leg: ${response["storyLeg"]}\n";
        // Update the options with the ones returned by the backend.
        currentOptions = List<String>.from(response["options"] ?? []);
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
            // Only show the button menu if there are options.
            currentOptions.isNotEmpty
                ? ElevatedButton(
              onPressed: () => showButtonMenu(context),
              child: Text("Choose an Option"),
            )
                : Container(),
          ],
        ),
      ),
    );
  }
}
