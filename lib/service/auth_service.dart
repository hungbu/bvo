import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Get current user
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  User? get firebaseUser => _firebaseAuth.currentUser;

  // Stream for listening to auth state changes
  Stream<GoogleSignInAccount?> get onAuthStateChanged => _googleSignIn.onCurrentUserChanged;

  // Sign in with Google
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      return googleUser;
    } catch (error) {
      print('Error signing in with Google: $error');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google
      await _googleSignIn.disconnect();
      
      // Sign out from Firebase
      await _firebaseAuth.signOut();
      
      // Clear all local storage data
      await clearAllLocalData();
      
      print('Successfully signed out');
    } catch (error) {
      print('Error signing out: $error');
      throw error;
    }
  }

  // Clear all local storage data
  Future<void> clearAllLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all data
      await prefs.clear();
      
      print('All local data cleared');
    } catch (error) {
      print('Error clearing local data: $error');
    }
  }

  // Clear specific data
  Future<void> clearUserSpecificData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // List of keys to remove (you can add more as needed)
      final keysToRemove = [
        'cached_topics',
        'user_profile',
        'user_stats',
        'auth_token',
        'refresh_token',
      ];
      
      for (String key in keysToRemove) {
        await prefs.remove(key);
      }
      
      // Remove all words data (keys starting with 'words_')
      final allKeys = prefs.getKeys();
      for (String key in allKeys) {
        if (key.startsWith('words_')) {
          await prefs.remove(key);
        }
      }
      
      print('User specific data cleared');
    } catch (error) {
      print('Error clearing user specific data: $error');
    }
  }

  // Check if user is signed in
  bool get isSignedIn => _googleSignIn.currentUser != null;

  // Silent sign in (for app startup)
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (error) {
      print('Error in silent sign in: $error');
      return null;
    }
  }
}
