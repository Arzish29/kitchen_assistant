import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lottie/lottie.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Recipe Generator',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F5F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE67E22),
          brightness: Brightness.light,
          primary: const Color(0xFFE67E22),
        ),
        textTheme: GoogleFonts.latoTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      home: const RecipeGeneratorPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RecipeGeneratorPage extends StatefulWidget {
  const RecipeGeneratorPage({super.key});

  @override
  State<RecipeGeneratorPage> createState() => _RecipeGeneratorPageState();
}

class _RecipeGeneratorPageState extends State<RecipeGeneratorPage> {
  Uint8List? _imageBytesForDisplay;
  String? _imageData;
  String _responseText = "";
  bool _isLoading = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  // --- STREAMING UPDATE: This ScrollController will help us auto-scroll
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    // A small delay ensures the widget has time to build before we scroll.
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile =
          await _picker.pickImage(source: source, imageQuality: 80);

      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(imageBytes);

        setState(() {
          _imageBytesForDisplay = imageBytes;
          _imageData = base64String;
          _responseText = "";
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick image: $e";
      });
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- STREAMING UPDATE: The entire _generateRecipe function is updated.
  Future<void> _generateRecipe() async {
    if (_imageData == null) {
      setState(() {
        _errorMessage = "Please select an image first.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _responseText = "";
    });

    final httpClient = http.Client();
    try {
      const apiKey = "AIzaSyDYl9O1Y1nVOgFaCcAOouNJ6Z9zJGhT4Fk"; // Replace with your actual API key
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:streamGenerateContent?key=$apiKey&alt=sse');

      const userPrompt =
          "Please identify all the primary ingredients in this image. Based on these ingredients, suggest three different dishes. After suggesting the dishes, provide a detailed, step-by-step recipe for EACH of the three suggestions. Please structure your response so that each dish suggestion is immediately followed by its complete recipe before moving to the next suggestion. Use clear headings for each section.";

      final payload = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": userPrompt},
              {
                "inlineData": {"mimeType": "image/jpeg", "data": _imageData}
              }
            ]
          }
        ]
      });

      var request = http.Request("POST", url);
      request.headers['Content-Type'] = 'application/json';
      request.body = payload;

      final response = await httpClient.send(request);

      // Listen to the stream of data
      response.stream.transform(utf8.decoder).listen(
        (chunk) {
          // The Gemini API returns SSE (Server-Sent Events) which might have "data: " prefix
          final lines = chunk.split('\n').where((line) => line.startsWith('data: '));
          for (final line in lines) {
            final jsonString = line.substring(6); // Remove "data: "
            try {
              final jsonResponse = jsonDecode(jsonString);
              final text = jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'];
              if (text != null) {
                setState(() {
                  _responseText += text;
                  _isLoading = false; // The first chunk has arrived, so we can stop the Lottie
                });
                _scrollToBottom();
              }
            } catch (e) {
              // Ignore chunks that are not valid JSON
            }
          }
        },
        onDone: () {
          // Stream is finished
        },
        onError: (error) {
          setState(() {
            _errorMessage = "An error occurred during streaming: $error";
            _isLoading = false;
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _errorMessage = "An error occurred: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kitchen AI Assistant 🍲',
          style: GoogleFonts.pacifico(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              const Color(0xFFFDF5EC)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          // --- STREAMING UPDATE: Using our scroll controller here
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 5.0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: GestureDetector(
                    onTap: _showImageSourceActionSheet,
                    child: Container(
                      height: 250,
                      color: Colors.grey.shade100,
                      child: _imageBytesForDisplay == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined,
                                    size: 50,
                                    color: Colors.grey.shade600),
                                const SizedBox(height: 12),
                                const Text("Tap to upload ingredients"),
                              ],
                            )
                          : Image.memory(_imageBytesForDisplay!,
                              fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading || _imageBytesForDisplay == null
                      ? null
                      : _generateRecipe,
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Create Recipe'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                _buildResultWidget(),
              ],
            ).animate().fadeIn(duration: 500.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildResultWidget() {
    Widget content;
    if (_isLoading) {
      content = Center(
        child: Column(
          children: [
            Lottie.asset('assets/cooking_animation.json',
                width: 150, height: 150),
            const SizedBox(height: 10),
            const Text("Whipping up something special..."),
          ],
        ),
      );
    } else if (_errorMessage != null) {
      content = Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: TextStyle(
                color: Colors.red.shade900, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_responseText.isNotEmpty) {
      content = Card(
        elevation: 2.0,
        color: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: MarkdownBody(data: _responseText, selectable: true),
        ),
      );
    } else {
      content =
          const Center(child: Text("Your delicious recipe will appear here."));
    }

    // --- STREAMING UPDATE: The key ensures the animation re-runs when the content changes
    return Animate(
      key: ValueKey(_responseText), // Use a key to re-trigger animation
      effects: const [FadeEffect(duration: Duration(milliseconds: 300))],
      child: content,
    );
  }
}