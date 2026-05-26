import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final TextEditingController nameController = TextEditingController();

  String? selectedLanguageCode;
  String? selectedTts;
  String? selectedLanguageName;

  List languages = [];

  @override
  void initState() {
    super.initState();
    loadLanguages();
    loadSavedData();
  }

  Future<void> loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    nameController.text = prefs.getString("user_name") ?? "";

    setState(() {
      selectedLanguageCode = prefs.getString("language_code");
      selectedLanguageName = prefs.getString("language_name");
      selectedTts = prefs.getString("tts_code");
    });
  }

  Future<void> loadLanguages() async {
    try {
      final url = Uri.parse(
        'https://gaffis.net/pulse/public/api/languages',
      );

      final res = await http.get(url);

      setState(() {
        languages = jsonDecode(res.body);
      });
    } catch (e) {}
  }

  Future<void> saveAndContinue() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your name"),
        ),
      );
      return;
    }

    if (selectedLanguageCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select language"),
        ),
      );
      return;
    }

    SharedPreferences prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      "user_name",
      nameController.text.trim(),
    );

    await prefs.setString(
      "language_code",
      selectedLanguageCode!,
    );

    await prefs.setString(
      "language_name",
      selectedLanguageName!,
    );

    await prefs.setString(
      "tts_code",
      selectedTts!,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          languageCode: selectedLanguageCode!,
          ttsCode: selectedTts!,
          languageName: selectedLanguageName!,
        ),
      ),
    );
  }

  InputDecoration inputStyle(
      String hint,
      IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: Colors.green.shade700,
      ),
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF5F7F6),

      body: Column(
        children: [

          /// Header
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade800,
                  Colors.green.shade500,
                ],
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.only(
                bottomLeft:
                    Radius.circular(35),
                bottomRight:
                    Radius.circular(35),
              ),
            ),

            child: SafeArea(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [

                  Container(
                    padding:
                        const EdgeInsets.all(
                            18),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,
                      shape:
                          BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors
                              .black12,
                          blurRadius: 15,
                        )
                      ],
                    ),
                    child: Icon(
                      Icons.agriculture,
                      color: Colors
                          .green.shade700,
                      size: 50,
                    ),
                  ),

                  const SizedBox(
                      height: 15),

                  const Text(
                    "Gaffis Krushi AI",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Colors.white,
                    ),
                  ),

                  const SizedBox(
                      height: 8),

                  const Text(
                    "Smart Farming Assistant",
                    style: TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.all(
                      24),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [

                  const SizedBox(
                      height: 20),

                  const Text(
                    "Enter Your Name",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                      height: 10),

                  TextField(
                    controller:
                        nameController,
                    decoration:
                        inputStyle(
                      "Your Name",
                      Icons.person,
                    ),
                  ),

                  const SizedBox(
                      height: 30),

                  const Text(
                    "Choose Language",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                      height: 10),

                  DropdownButtonFormField(
                    value:
                        selectedLanguageCode,
                    decoration:
                        inputStyle(
                      "Select Language",
                      Icons.language,
                    ),

                    items:
                        languages.map(
                      (lang) {
                        return DropdownMenuItem(
                          value:
                              lang['code'],
                          child:
                              Text(
                            lang['name'],
                          ),
                          onTap: () {
                            selectedTts =
                                lang['tts'];

                            selectedLanguageName =
                                lang['name'];
                          },
                        );
                      },
                    ).toList(),

                    onChanged:
                        (value) {
                      setState(() {
                        selectedLanguageCode =
                            value
                                .toString();
                      });
                    },
                  ),

                  const SizedBox(
                      height: 60),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 60,
                    child:
                        ElevatedButton(
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            Colors
                                .green
                                .shade700,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  18),
                        ),
                        elevation: 5,
                      ),
                      onPressed:
                          saveAndContinue,
                      child:
                          const Text(
                        "Continue",
                        style:
                            TextStyle(
                          fontSize:
                              18,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Colors
                                  .white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}