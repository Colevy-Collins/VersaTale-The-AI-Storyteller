import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';
import 'login_screen.dart';

class StoryScreen extends StatefulWidget {
  final String initialLeg;
  final List<String> options; // Initial options returned by the backend.
  final String storyTitle;

  const StoryScreen({
    Key? key,
    required this.initialLeg,
    required this.options,
    required this.storyTitle,
  }) : super(key: key);

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final AuthService authService = AuthService();
  final StoryService storyService = StoryService();
  final TextEditingController textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late List<String> currentOptions;
  bool _isRequestInProgress = false;
  // Add a state variable for the story title.
  String _storyTitle = "Interactive Story";

  @override
  void initState() {
    super.initState();
    // Display the initial story leg and options.
    textController.text = widget.initialLeg;
    currentOptions = widget.options;
    _storyTitle = widget.storyTitle;
    // Scroll to bottom after initial frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void logout(BuildContext context) async {
    await authService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void onMenuItemSelected(String decision) {
    setState(() {
      textController.text += "\n\nUser choice: $decision\n";
    });
    // Call backend for the next story leg using the selected decision.
    getNextStoryLeg(decision);
  }

  void saveStory() async {
    try {
      final response = await storyService.saveStory();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response["message"] ?? "Story saved successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving story: $e")),
      );
    }
  }

  void showButtonMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 250,
          child: ListView.builder(
            itemCount: currentOptions.length,
            itemBuilder: (context, index) {
              // If the option is "The story ends", disable the button.
              bool isFinal = currentOptions[index] == "The story ends";
              return ListTile(
                title: ElevatedButton(
                  onPressed: _isRequestInProgress || isFinal
                      ? null
                      : () {
                    onMenuItemSelected(currentOptions[index]);
                    Navigator.pop(context); // Close menu
                  },
                  child: Text(
                    isFinal ? "The story ends" : currentOptions[index],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> getNextStoryLeg(String decision) async {
    // Prevent multiple submissions until a response is returned.
    if (_isRequestInProgress) return;
    setState(() {
      _isRequestInProgress = true;
    });
    try {
      final response = await storyService.getNextLeg(decision: decision);
      setState(() {
        textController.text += "\n\nNew story leg: ${response["storyLeg"]}\n";
        // Update options from the response.
        currentOptions = List<String>.from(response["options"] ?? []);
        // Update the story title if it exists in the response.
        if (response.containsKey("storyTitle")) {
          _storyTitle = response["storyTitle"];
        }
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        textController.text += "\n\nError calling backend: $e\n";
      });
    } finally {
      setState(() {
        _isRequestInProgress = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Use the dynamic story title.
        title: Text(_storyTitle),
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
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
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
            currentOptions.isNotEmpty
                ? ElevatedButton(
              onPressed: _isRequestInProgress ? null : () => showButtonMenu(context),
              child: Text("Choose Next Action"),
            )
                : Container(),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isRequestInProgress ? null : saveStory,
              child: Text("Save Story"),
            ),
          ],
        ),
      ),
    );
  }
}

