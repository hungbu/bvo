import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:bvo/repository/dictionary.dart';

import 'theme/purple_theme.dart';
import 'screen/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoogleSignInAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    GoogleSignIn().onCurrentUserChanged.listen((account) {
      setState(() {
        _currentUser = account;
      });
    });
    GoogleSignIn().signInSilently();
  }

  Future<void> _handleSignIn() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(googleUser.email)
            .set({
          'displayName': googleUser.displayName,
          'email': googleUser.email,
        });
      }
    } catch (error) {
      print(error);
    }
  }

  Future<void> _handleSignOut() async {
    await GoogleSignIn().disconnect();
    setState(() {
      _currentUser = null;
    });
  }

  // Temporary function to upload data to Firestore
  Future<void> _uploadDictionaryToFirestore() async {
    final firestore = FirebaseFirestore.instance;
    final wordsCollection = firestore.collection('words');
    final topicsCollection = firestore.collection('topics');
    final allWords = dictionary; // from dictionary.dart

    // Get unique topics
    final topics = allWords.map((word) => word['topic']).toSet();

    // Upload topics
    for (var topicName in topics) {
      if (topicName != null) {
        await topicsCollection.doc(topicName).set({'name': topicName});
      }
    }

    // Upload words
    for (var wordData in allWords) {
      // A simple way to create a unique ID is to use the english word
      final wordId = wordData['en']?.replaceAll(' ', '_').toLowerCase();
      if (wordId != null && wordId.isNotEmpty) {
        await wordsCollection.doc(wordId).set({
          'en': wordData['en'],
          'vi': wordData['vi'],
          'pronunciation': wordData['pronunciation'],
          'sentence': wordData['sentence'],
          'topic': wordData['topic'],
        });
      }
    }

    print('Data upload completed!');
  }


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Bun Vocabulary',
        debugShowCheckedModeBanner: false,
        theme: PurpleTheme.getTheme(),
        home: _buildBody());
  }

  Widget _buildBody() {
    GoogleSignInAccount? user = _currentUser;
    if (user != null) {
      return HomeScreen();
    } else {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "You are not signed in.",
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _handleSignIn,
                child: const Text("Sign in with Google"),
              ),
              const SizedBox(height: 20),
              // Temporary button to trigger the upload
              ElevatedButton(
                onPressed: _uploadDictionaryToFirestore,
                child: const Text("Upload Dictionary to Firestore"),
              ),
            ],
          ),
        ),
      );
    }
  }
}
