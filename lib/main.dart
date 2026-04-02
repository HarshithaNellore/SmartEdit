import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'providers/project_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/collaboration_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/editor/video_editor_screen.dart';
import 'screens/editor/photo_editor_screen.dart';
import 'screens/editor/collage_editor_screen.dart';
import 'screens/ai_features/ai_features_screen.dart';

import 'screens/collaboration/collaboration_screen.dart';
import 'screens/export/export_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e\nThis is expected if flutterfire configure hasn\'t been run yet.');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const SmartCutApp());
}

class SmartCutApp extends StatelessWidget {
  const SmartCutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => CollaborationProvider()),
      ],
      child: MaterialApp(
        title: 'SmartCut',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
        onGenerateRoute: (settings) {
          final routes = <String, WidgetBuilder>{
            '/home': (context) => const HomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/video-editor': (context) => const VideoEditorScreen(),
            '/photo-editor': (context) => const PhotoEditorScreen(),
            '/collage-editor': (context) => const CollageEditorScreen(),
            '/ai-features': (context) => const AIFeaturesScreen(),

            '/collaboration': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return CollaborationScreen(projectId: args?['projectId'] as String? ?? '');
            },
            '/export': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return ExportScreen(
                clips: args?['clips'] as List<VideoClip>?,
                audioPath: args?['audioPath'] as String?,
                audioTrimStartMs: args?['audioTrimStartMs'] as int? ?? 0,
                audioTrimEndMs: args?['audioTrimEndMs'] as int? ?? 0,
                textOverlays: args?['textOverlays'] as List<VideoTextOverlay>?,
              );
            },
            '/settings': (context) => const SettingsScreen(),
          };
          final builder = routes[settings.name];
          if (builder != null) {
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (context, animation, secondaryAnimation) => builder(context),
              transitionDuration: const Duration(milliseconds: 150),
              reverseTransitionDuration: const Duration(milliseconds: 150),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          }
          return null;
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );

    _controller.forward();

    // Check auth state after splash animation
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final isLoggedIn = await auth.tryAutoLogin();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          isLoggedIn ? '/home' : '/login',
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D1A), Color(0xFF1A0A2E), Color(0xFF0D0D1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryPurple.withAlpha(100),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // App Name
                        ShaderMask(
                          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                          child: Text(
                            'SmartCut',
                            style: GoogleFonts.outfit(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI-Powered Photo & Video Editor',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryPurple.withAlpha(180),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
