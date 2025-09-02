import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'theme/purple_theme.dart';
import 'screen/main_layout.dart';
import 'screen/login_screen.dart';
import 'service/auth_service.dart';
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
    
    // Listen to auth state changes
    AuthService().onAuthStateChanged.listen((account) {
      setState(() {
        _currentUser = account;
      });
    });
    
    // Try silent sign in
    _trySignInSilently();
  }

  Future<void> _trySignInSilently() async {
    final user = await AuthService().signInSilently();
    setState(() {
      _currentUser = user;
    });
  }






  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bun Vocabulary',
      debugShowCheckedModeBanner: false,
      theme: PurpleTheme.getTheme(),
      initialRoute: _currentUser != null ? '/main' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainLayout(),
      },
    );
  }


}
