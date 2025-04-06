import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/story_service.dart';
import 'main_splash_screen.dart';

// Define menu options, including a close menu option.
enum _MenuOption { backToScreen, previousLeg, viewFullStory, saveStory, logout, closeMenu }

class StoryScreen extends StatefulWidget {
  final String initialLeg;
  final List<String> options;
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
  String _storyTitle = "Interactive Story";

  @override
  void initState() {
    super.initState();
    textController.text = widget.initialLeg;
    currentOptions = widget.options;
    _storyTitle = widget.storyTitle;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  /// Shows a confirmation dialog before reverting to the previous leg.
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

  /// Logs out the user and navigates to the splash screen.
  void logout(BuildContext context) async {
    await authService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainSplashScreen()),
    );
  }

  /// Dispatches actions based on the selected menu option.
  void onMenuItemSelected(_MenuOption option) {
    switch (option) {
      case _MenuOption.backToScreen:
        Navigator.of(context).pop();
        break;
      case _MenuOption.previousLeg:
        _confirmAndGoBack();
        break;
      case _MenuOption.viewFullStory:
        viewFullStoryDialog(context);
        break;
      case _MenuOption.saveStory:
        saveStory();
        break;
      case _MenuOption.logout:
        logout(context);
        break;
      case _MenuOption.closeMenu:
      // Close menu automatically when an item is selected; no further action needed.
        break;
    }
  }

  /// Called when a next action option is selected.
  void onMenuItemSelectedNext(String decision) async {
    setState(() => _isRequestInProgress = true);
    try {
      final response = await storyService.getNextLeg(decision: decision);
      textController.text = response["storyLeg"] ?? "No story leg returned.";
      currentOptions = List<String>.from(response["options"] ?? []);
      if (response.containsKey("storyTitle")) {
        _storyTitle = response["storyTitle"];
      }
    } catch (e) {
      showErrorDialog(context, "$e");
    } finally {
      setState(() => _isRequestInProgress = false);
      _scrollToBottom();
    }
  }

  /// Displays the full story in a dialog.
  void viewFullStoryDialog(BuildContext context) async {
    try {
      final response = await storyService.getFullStory();
      final String fullStory = response["initialLeg"] ?? "Your story will be here";
      final List<String> dialogOptions = List<String>.from(response["options"] ?? []);
      showDialog(
        context: context,
        builder: (context) {
          return FullStoryDialog(
            fullStory: fullStory,
            dialogOptions: dialogOptions,
            onOptionSelected: (option) {
              Navigator.of(context).pop();
              onMenuItemSelectedNext(option);
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$e")),
      );
    }
  }

  /// Retrieves the previous story leg.
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
      showErrorDialog(context, "$e");
    } finally {
      setState(() => _isRequestInProgress = false);
      _scrollToBottom();
    }
  }

  /// Saves the current story.
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
        SnackBar(content: Text("Error saving story: $e", style: GoogleFonts.atma())),
      );
    }
  }

  /// Auto-scrolls to the bottom of the story text.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
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
    // Use an AppBar with no default back arrow; title in a FittedBox for dynamic sizing.
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white.withOpacity(0.7),
        elevation: 8,
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _storyTitle,
            style: GoogleFonts.atma(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<_MenuOption>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: onMenuItemSelected,
            itemBuilder: (context) => <PopupMenuEntry<_MenuOption>>[
              PopupMenuItem<_MenuOption>(
                value: _MenuOption.backToScreen,
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios, color: Colors.black),
                    const SizedBox(width: 8),
                    Text("Back a Screen", style: GoogleFonts.atma()),
                  ],
                ),
              ),
              PopupMenuItem<_MenuOption>(
                value: _MenuOption.previousLeg,
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, color: Colors.black),
                    const SizedBox(width: 8),
                    Text("Previous Leg", style: GoogleFonts.atma()),
                  ],
                ),
              ),
              PopupMenuItem<_MenuOption>(
                value: _MenuOption.viewFullStory,
                child: Row(
                  children: [
                    const Icon(Icons.visibility, color: Colors.black),
                    const SizedBox(width: 8),
                    Text("View Full Story", style: GoogleFonts.atma()),
                  ],
                ),
              ),
              PopupMenuItem<_MenuOption>(
                value: _MenuOption.saveStory,
                child: Row(
                  children: [
                    const Icon(Icons.save, color: Colors.black),
                    const SizedBox(width: 8),
                    Text("Save Story", style: GoogleFonts.atma()),
                  ],
                ),
              ),
              PopupMenuItem<_MenuOption>(
                value: _MenuOption.logout,
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.black),
                    const SizedBox(width: 8),
                    Text("Logout", style: GoogleFonts.atma()),
                  ],
                ),
              ),
              PopupMenuItem<_MenuOption>(
                value: _MenuOption.closeMenu,
                child: Row(
                  children: [
                    const Icon(Icons.close, color: Colors.black),
                    const SizedBox(width: 8),
                    Text("Close Menu", style: GoogleFonts.atma()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
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
                    if (currentOptions.isNotEmpty)
                      ElevatedButton(
                        onPressed: _isRequestInProgress ? null : () => showButtonMenu(context),
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

  /// Displays a bottom sheet with the current options.
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC27B31),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isRequestInProgress || isFinal
                      ? null
                      : () {
                    onMenuItemSelectedNext(currentOptions[index]);
                    Navigator.pop(context); // close bottom sheet
                  },
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
}

/// Dialog widget for displaying the full story and current options.
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
            // NOTE: The “Choose Next Action” button was moved from here into the actions below.
          ],
        ),
      ),
      actions: [
        // Show "Choose Next Action" in the bottom bar if there are options available:
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
                              Navigator.pop(context);
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Close", style: GoogleFonts.atma()),
        ),
      ],
    );
  }
}

/// Helper function to display backend errors in a dialog.
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
