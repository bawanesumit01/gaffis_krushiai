import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'call_screen.dart';

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
          localeId: widget.ttsCode,
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
      if (text.isNotEmpty) messages.add({'from': 'user', 'text': text});
      if (selectedImage != null) {
        messages.add({'from': 'user', 'image': selectedImage!.path});
      }
      isTyping = true;
    });

    scrollToBottom();

    final uri = Uri.parse('https://gaffis.net/pulse/public/api/chat');
    final request = http.MultipartRequest('POST', uri);
    request.fields['message'] = text;
    request.fields['language'] = widget.languageCode;

    if (selectedImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', selectedImage!.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      setState(() => isTyping = false);
      return;
    }

    final decoded = jsonDecode(response.body);
    final reply = decoded['reply'] ?? 'No response';

    setState(() {
      isTyping = false;
      selectedImage = null;
      messages.add({'from': 'ai', 'text': reply});
    });

    scrollToBottom();
    // ✅ No TTS here — chat screen is text only
    // Voice calls handled by CallScreen via Vapi
  }

  Widget chatBubble(Map<String, String> m) {
    final isUser = m['from'] == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
                child: Image.file(File(m['image']!),
                    width: 220, height: 180, fit: BoxFit.cover),
              ),
            if (m.containsKey('text'))
              Padding(
                padding: EdgeInsets.only(top: m.containsKey('image') ? 8 : 0),
                child: Text(m['text']!,
                    style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green.shade700,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                    languageCode: widget.languageCode,
                    ttsCode: widget.ttsCode,
                    languageName: widget.languageName,
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
                const Text('Gaffis Krushi AI',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(widget.languageName,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70)),
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
                      child: Text('Krushi AI is typing...',
                          style: TextStyle(color: Colors.grey)),
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
                      child: Image.file(selectedImage!,
                          height: 100, width: 120, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 18),
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
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 40),
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
                          child: Wrap(children: [
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
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor:
                      isListening ? Colors.red : Colors.green.shade700,
                  child: IconButton(
                    icon: Icon(isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white),
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
                          horizontal: 20, vertical: 14),
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