import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_screen.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  Future<List> fetchLanguages() async {
    final url = Uri.parse('https://gaffis.net/pulse/public/api/languages');

    final res = await http.get(url).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Failed to load languages');
    }

    return jsonDecode(res.body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Choose Your Language',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FutureBuilder(
        future: fetchLanguages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Failed to load languages",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      (context as Element).reassemble();
                    },
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          final languages = snapshot.data as List;

          if (languages.isEmpty) {
            return const Center(child: Text("No languages available"));
          }

          return ListView.builder(
            itemCount: languages.length,
            itemBuilder: (context, i) {
              final lang = languages[i];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          languageCode: lang['code'],
                          ttsCode: lang['tts'],
                          languageName: lang['name'],
                        ),
                      ),
                    );
                  },
                  child: Text(
                    lang['name'],
                    style: const TextStyle(fontSize: 22, color: Colors.white),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
