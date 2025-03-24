import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';
import 'login_screen.dart';

class StoryScreen extends StatefulWidget {
  final String initialLeg;
  final List<String> options; // Initial options from the backend.
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

  // Controller for the story text
  final TextEditingController textController = TextEditingController();

  // Controller for the Scrollbar + SingleChildScrollView
  final ScrollController _scrollController = ScrollController();

  // The current set of options from the backend
  late List<String> currentOptions;

  bool _isRequestInProgress = false;
  String _storyTitle = "Interactive Story";

  @override
  void initState() {
    super.initState();
    textController.text = widget.initialLeg;
    currentOptions = widget.options;
    _storyTitle = widget.storyTitle;

    // Once the layout is built, auto-scroll to bottom (if multiple lines of text)
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  /// Shows a confirmation dialog before going "Back."
  void _confirmAndGoBack() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Warning", style: GoogleFonts.atma()),
          content: Text(
            "If you go back and then choose the same option, the next leg may be different. Continue?",
            style: GoogleFonts.atma(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel", style: GoogleFonts.atma()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Continue", style: GoogleFonts.atma()),
            ),
          ],
        );
      },
    );

    if (result == true) {
      getPreviousStoryLeg();
    }
  }

  /// Logs out the user and navigates back to the login screen.
  void logout(BuildContext context) async {
    await authService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  /// Called when the user selects an option to generate the next leg of the story.
  void onMenuItemSelected(String decision) async {
    setState(() => _isRequestInProgress = true);
    try {
      final response = await storyService.getNextLeg(decision: decision);

      textController.text = response["storyLeg"] ?? "No story leg returned.";
      currentOptions = List<String>.from(response["options"] ?? []);

      if (response.containsKey("storyTitle")) {
        _storyTitle = response["storyTitle"];
      }
    } catch (e) {
      showErrorDialog(context, "Error calling backend: $e");
    } finally {
      setState(() => _isRequestInProgress = false);
      _scrollToBottom();
    }
  }

  /// Shows a bottom sheet with the current options.
  void showButtonMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 250,
          child: ListView.builder(
            itemCount: currentOptions.length,
            itemBuilder: (context, index) {
              bool isFinal = currentOptions[index] == "The story ends";
              return ListTile(
                title: ElevatedButton(
                  onPressed: _isRequestInProgress || isFinal
                      ? null
                      : () {
                    onMenuItemSelected(currentOptions[index]);
                    Navigator.pop(context); // close the bottom sheet
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC27B31),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isFinal ? "The story ends" : currentOptions[index],
                    style: GoogleFonts.atma(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Fetch the "full story so far" from the backend and display it in a dialog.
  void viewFullStoryDialog(BuildContext context) async {
    try {
      final response = await storyService.getFullStory();
      final String fullStory = response["initialLeg"] ?? "";
      final List<String> dialogOptions = List<String>.from(response["options"] ?? []);

      showDialog(
        context: context,
        builder: (context) {
          return FullStoryDialog(
            fullStory: fullStory,
            dialogOptions: dialogOptions,
            onOptionSelected: (option) {
              Navigator.of(context).pop(); // close the dialog
              onMenuItemSelected(option);   // fetch next leg
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching full story: $e")),
      );
    }
  }

  /// Reverts the story to the previous leg (called only after user confirms).
  void getPreviousStoryLeg() async {
    if (_isRequestInProgress) return;

    setState(() => _isRequestInProgress = true);

    try {
      final response = await storyService.getPreviousLeg();

      textController.text = response["storyLeg"] ?? "No story leg returned.";
      currentOptions = List<String>.from(response["options"] ?? []);

      if (response.containsKey("storyTitle")) {
        _storyTitle = response["storyTitle"];
      }
    } catch (e) {
      showErrorDialog(context, "Error calling backend (Back): $e");
    } finally {
      setState(() => _isRequestInProgress = false);
      _scrollToBottom();
    }
  }

  /// Saves the current story on the server.
  void saveStory() async {
    try {
      final response = await storyService.saveStory();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response["message"] ?? "Story saved successfully.",
            style: GoogleFonts.atma(),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving story: $e", style: GoogleFonts.atma()),
        ),
      );
    }
  }

  /// Auto-scroll to the bottom of the text field
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
      // We still use a large toolbarHeight
      // But we wrap our content in a FittedBox, so it shrinks if needed.
      appBar: AppBar(
        automaticallyImplyLeading: true,
        centerTitle: true,
        toolbarHeight: 120,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _storyTitle,
                  style: GoogleFonts.atma(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Back button (with confirmation)
                    TextButton(
                      onPressed: _isRequestInProgress ? null : _confirmAndGoBack,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Back",
                        style: GoogleFonts.atma(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // View Full Story
                    TextButton(
                      onPressed: () => viewFullStoryDialog(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "View Full Story",
                        style: GoogleFonts.atma(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Save Story
                    TextButton(
                      onPressed: saveStory,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFC27B31),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Save Story",
                        style: GoogleFonts.atma(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Logout icon
                    Container(
                      width: 50,
                      height: 40,
                      child: IconButton(
                        icon: Icon(Icons.logout),
                        color: Colors.white,
                        onPressed: () => logout(context),
                        tooltip: "Logout",
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            // Constrain the max width for desktops, allow full width on smaller devices
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 800, // adjust as needed
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  // The text area expands in the remaining space
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
                              decoration: const InputDecoration.collapsed(
                                hintText: "Story will appear here...",
                              ),
                              style: GoogleFonts.atma(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Show the "Choose Next Action" button only if options exist
                    if (currentOptions.isNotEmpty)
                      ElevatedButton(
                        onPressed:
                        _isRequestInProgress ? null : () => showButtonMenu(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC27B31),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Choose Next Action",
                          style: GoogleFonts.atma(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Simple dialog widget to display the full story and the current options
class FullStoryDialog extends StatelessWidget {
  final String fullStory;
  final List<String> dialogOptions;
  final ValueChanged<String> onOptionSelected;

  const FullStoryDialog({
    Key? key,
    required this.fullStory,
    required this.dialogOptions,
    required this.onOptionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Full Story So Far", style: GoogleFonts.atma()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fullStory, style: GoogleFonts.atma()),
            const SizedBox(height: 16),
            if (dialogOptions.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return Container(
                        height: 250,
                        child: ListView.builder(
                          itemCount: dialogOptions.length,
                          itemBuilder: (context, index) {
                            bool isFinal = dialogOptions[index] == "The story ends";
                            return ListTile(
                              title: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC27B31),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: isFinal
                                    ? null
                                    : () {
                                  onOptionSelected(dialogOptions[index]);
                                  Navigator.pop(context); // close bottom sheet
                                },
                                child: Text(
                                  isFinal ? "The story ends" : dialogOptions[index],
                                  style: GoogleFonts.atma(fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC27B31),
                ),
                child: Text(
                  "Choose Next Action",
                  style: GoogleFonts.atma(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Close", style: GoogleFonts.atma()),
        ),
      ],
    );
  }
}

/// Helper function to show backend errors in a dialog
void showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}
