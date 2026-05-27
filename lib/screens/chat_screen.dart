import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  final String languageCode;
  final String ttsCode;
  final String languageName;

  const ChatScreen({
    super.key,
    required this.languageCode,
    required this.ttsCode,
    required this.languageName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late stt.SpeechToText speech;
  bool isListening = false;
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();
  String userKey = "";
  String userName = "";
  String currentChatId = "";
  List<Map<String, dynamic>> recentChats = [];
  String selectedLanguageName = "";
  String selectedLanguageCode = "";
  String selectedTtsCode = "";
  bool showRecentChats = false;

  final controller = TextEditingController();
  // ✅ REMOVED flutterTts — no longer needed
  final List<Map<String, String>> messages = [];
  final ScrollController scrollController = ScrollController();

  bool isTyping = false;

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    speech = stt.SpeechToText();

    selectedLanguageName = widget.languageName;
    selectedLanguageCode = widget.languageCode;
    selectedTtsCode = widget.ttsCode;

    loadName();
    loadSavedLanguage();
    initUserKey();
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    speech.stop();

    super.dispose();
  }

  Future<void> deleteChat(String chatId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat"),
        content: const Text("Are you sure you want to delete this chat?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // remove chat messages
    await prefs.remove("chat_${userKey}_$chatId");

    // remove from recent list
    recentChats.removeWhere((e) => e["id"] == chatId);

    await prefs.setString("recent_chats", jsonEncode(recentChats));

    // if current opened chat deleted
    if (currentChatId == chatId) {
      await clearCurrentChat();
    }

    setState(() {});
  }

  Future<void> clearCurrentChat() async {
    currentChatId = const Uuid().v4();

    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString("current_chat", currentChatId);

    setState(() {
      messages.clear();
    });
  }

  Future<void> loadName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      userName = prefs.getString("user_name") ?? "";
    });
  }

  Future<void> initUserKey() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? mobileNo = prefs.getString("mobile_no");

    if (mobileNo != null && mobileNo.isNotEmpty) {
      userKey = mobileNo;
    } else {
      String? deviceId = prefs.getString("device_id");

      if (deviceId == null) {
        deviceId = const Uuid().v4();

        await prefs.setString("device_id", deviceId);
      }

      userKey = deviceId;
    }

    await createOrLoadChat();
    await loadRecentChats();
  }

  Future<void> createOrLoadChat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    currentChatId = prefs.getString("current_chat") ?? const Uuid().v4();

    await prefs.setString("current_chat", currentChatId);

    await loadChatHistory();
  }

  Future<void> loadRecentChats() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString("recent_chats");

    try {
      if (saved != null && saved.isNotEmpty) {
        final decoded = jsonDecode(saved);

        if (decoded is List) {
          setState(() {
            recentChats = decoded
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        } else {
          recentChats = [];
        }
      } else {
        recentChats = [];
      }
    } catch (e) {
      recentChats = [];

      await prefs.remove("recent_chats");
    }
  }

  Future<void> saveRecentChats(String title) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    bool exists = recentChats.any((e) => e["id"] == currentChatId);

    if (!exists) {
      recentChats.insert(0, {"id": currentChatId, "title": title});

      await prefs.setString("recent_chats", jsonEncode(recentChats));
    }
  }

  Future<void> loadSelectedChat(String chatId) async {
    currentChatId = chatId;

    await loadChatHistory();

    Navigator.pop(context);
  }

  Future<void> saveChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String key = "chat_${userKey}_$currentChatId";

    List<String> jsonList = messages.map((e) => jsonEncode(e)).toList();

    await prefs.setStringList(key, jsonList);
  }

  Future<void> loadChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String key = "chat_${userKey}_$currentChatId";

    List<String>? saved = prefs.getStringList(key);

    setState(() {
      messages.clear();

      if (saved != null) {
        messages.addAll(
          saved.map((e) => Map<String, String>.from(jsonDecode(e))),
        );
      }
    });

    scrollToBottom();
  }

  Future<void> toggleListening() async {
    if (!isListening) {
      bool available = await speech.initialize(
        onStatus: (status) {
          if (status == 'done') setState(() => isListening = false);
        },
        onError: (error) {
          setState(() => isListening = false);
        },
      );

      if (available) {
        setState(() => isListening = true);
        await speech.listen(
          localeId: selectedTtsCode,
          onResult: (result) {
            setState(() {
              controller.text = result.recognizedWords;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            });
          },
        );
      }
    } else {
      setState(() => isListening = false);
      await speech.stop();
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();

    if (text.isEmpty && selectedImage == null) return;

    controller.clear();

    setState(() {
      if (text.isNotEmpty) {
        messages.add({'from': 'user', 'text': text});
      }

      if (selectedImage != null) {
        messages.add({'from': 'user', 'image': selectedImage!.path});
      }

      isTyping = true;
    });

    scrollToBottom();

    // save user message immediately
    await saveChatHistory();

    try {
      final uri = Uri.parse('https://gaffis.net/pulse/public/api/chat');

      final request = http.MultipartRequest('POST', uri);

      request.fields['message'] = text;

      request.fields['language'] = selectedLanguageCode;

      // send previous history also
      final recentHistory = messages.length > 20
          ? messages.sublist(messages.length - 20)
          : messages;

      request.fields['history'] = jsonEncode(recentHistory);

      if (selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', selectedImage!.path),
        );
      }

      final streamed = await request.send();

      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw Exception();
      }

      final decoded = jsonDecode(response.body);

      final reply = decoded['reply'] ?? "No response";

      setState(() {
        isTyping = false;
        selectedImage = null;

        messages.add({'from': 'ai', 'text': reply});
      });

      await saveChatHistory();

      scrollToBottom();
    } catch (e) {
      setState(() {
        isTyping = false;

        messages.add({'from': 'ai', 'text': 'Something went wrong'});
      });
    }

    await saveChatHistory();
    if (text.isNotEmpty) {
      await saveRecentChats(text);
    }
  }

  Future<void> loadSavedLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      selectedLanguageCode =
          prefs.getString("language_code") ?? widget.languageCode;

      selectedLanguageName =
          prefs.getString("language_name") ?? widget.languageName;

      selectedTtsCode = prefs.getString("tts_code") ?? widget.ttsCode;
    });
  }

  Widget chatBubble(Map<String, String> m) {
    final isUser = m['from'] == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isUser ? Colors.green.shade600 : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.containsKey('image'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(m['image']!),
                  width: 220,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            if (m.containsKey('text'))
              Padding(
                padding: EdgeInsets.only(top: m.containsKey('image') ? 8 : 0),
                child: Text(
                  m['text']!,
                  style: TextStyle(
                    color: isUser ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, left: 20, bottom: 20),
              decoration: BoxDecoration(color: Colors.green.shade700),

              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.green, size: 30),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName.isEmpty ? "Guest User" : userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          selectedLanguageName,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.language),
              title: const Text("Change Language"),

              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) {
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          title: const Text("English"),
                          onTap: () async {
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();

                            await prefs.setString("language_code", "en");
                            await prefs.setString("language_name", "English");
                            await prefs.setString("tts_code", "en-US");

                            setState(() {
                              selectedLanguageCode = "en";
                              selectedLanguageName = "English";
                              selectedTtsCode = "en-US";
                            });

                            Navigator.pop(context);
                          },
                        ),

                        ListTile(
                          title: const Text("Hindi"),
                          onTap: () async {
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();

                            await prefs.setString("language_code", "hi");
                            await prefs.setString("language_name", "Hindi");
                            await prefs.setString("tts_code", "hi-IN");

                            setState(() {
                              selectedLanguageCode = "hi";
                              selectedLanguageName = "Hindi";
                              selectedTtsCode = "hi-IN";
                            });

                            Navigator.pop(context);
                          },
                        ),

                        ListTile(
                          title: const Text("Marathi"),
                          onTap: () async {
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();

                            await prefs.setString("language_code", "mr");
                            await prefs.setString("language_name", "Marathi");
                            await prefs.setString("tts_code", "mr-IN");

                            setState(() {
                              selectedLanguageCode = "mr";
                              selectedLanguageName = "Marathi";
                              selectedTtsCode = "mr-IN";
                            });

                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.add),
              title: const Text("New Chat"),
              onTap: () async {
                Navigator.pop(context);

                await clearCurrentChat();
              },
            ),

            ExpansionTile(
              leading: const Icon(Icons.history),
              title: const Text("Recent Chats"),
              initiallyExpanded: showRecentChats,

              onExpansionChanged: (value) {
                setState(() {
                  showRecentChats = value;
                });
              },

              children: recentChats.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          "No recent chats",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ]
                  : recentChats.map((chat) {
                      return ListTile(
                        leading: const Icon(Icons.chat),

                        title: Text(
                          chat["title"],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        onTap: () {
                          loadSelectedChat(chat["id"]);
                        },

                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),

                          onPressed: () {
                            deleteChat(chat["id"]);
                          },
                        ),
                      );
                    }).toList(),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green.shade700,

        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    isVideo: false,
                    languageCode: selectedLanguageCode,
                    ttsCode: selectedTtsCode,
                    languageName: selectedLanguageName,
                  ),
                ),
              );
            },
          ),
        ],

        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.agriculture, color: Colors.green),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName.isEmpty ? "Gaffis Krushi AI" : "Hi, $userName",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                Text(
                  selectedLanguageName,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length + (isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length && isTyping) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Krushi AI is typing...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return chatBubble(messages[index]);
              },
            ),
          ),

          // Image preview
          if (selectedImage != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        selectedImage!,
                        height: 100,
                        width: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => setState(() => selectedImage = null),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Input bar
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 60),
            child: Row(
              children: [
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: Colors.green.shade700,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera),
                                title: const Text('Camera'),
                                onTap: () {
                                  Navigator.pop(context);
                                  pickImage(ImageSource.camera);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo),
                                title: const Text('Gallery'),
                                onTap: () {
                                  Navigator.pop(context);
                                  pickImage(ImageSource.gallery);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: isListening
                      ? Colors.red
                      : Colors.green.shade700,
                  child: IconButton(
                    icon: Icon(
                      isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                    onPressed: toggleListening,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Speak or type your question...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.green.shade700,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
