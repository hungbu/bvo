import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple,
              Color(0xFF7B1FA2), // Purple 700
              Color(0xFF4A148C), // Purple 900
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 150,
                height: 150,
                child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image not found
                      return const Icon(
                        Icons.school,
                        size: 50,
                        color: Colors.white,
                      );
                    },
                  
                ),
              ),
              const SizedBox(height: 30),
              
               // App Name
               const Text(
                 'Đông Sơn Go',
                 style: TextStyle(
                   color: Colors.white,
                   fontSize: 28,
                   fontWeight: FontWeight.bold,
                   letterSpacing: 1.2,
                 ),
               ),
              const SizedBox(height: 8),
              
              // App Tagline
              const Text(
                'Học từ vựng thông minh',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 40),
              
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              
              // Loading text
              const Text(
                'Đang khởi động...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
