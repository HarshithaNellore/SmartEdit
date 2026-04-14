import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late AnimationController _bgController;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);
    _bgAnim = Tween<double>(begin: -0.3, end: 0.3).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
      context.read<AuthProvider>().clearError();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    bool success;
    if (_isLogin) {
      success = await auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      success = await auth.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF0D0D1A),
                  Color(0xFF1A0A2E),
                  Color(0xFF0D0D1A),
                ],
                begin: Alignment(_bgAnim.value, -1),
                end: Alignment(-_bgAnim.value, 1),
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 40),
                  _buildAuthCard(),
                  const SizedBox(height: 24),
                  _buildToggle(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return FadeInDown(
      duration: const Duration(milliseconds: 800),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withAlpha(80),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              'SmartCut',
              style: GoogleFonts.outfit(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'AI-Powered Photo & Video Editor',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      delay: const Duration(milliseconds: 200),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withAlpha(20),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'Sign in to continue editing'
                        : 'Join SmartCut to start creating',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Error message
                  if (auth.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withAlpha(60),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.error!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Name field (signup only)
                  if (!_isLogin) ...[
                    _buildField(
                      controller: _nameController,
                      hint: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email field
                  _buildField(
                    controller: _emailController,
                    hint: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  _buildField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Password is required';
                      }
                      if (val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  // Confirm password (signup only)
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _confirmController,
                      hint: 'Confirm Password',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (val) {
                        if (val != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Submit button
                  _buildSubmitButton(auth.isLoading),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withAlpha(8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withAlpha(15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withAlpha(15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.withAlpha(120)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: GoogleFonts.inter(fontSize: 11),
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _submit,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: isLoading
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryPurple.withAlpha(120),
                    AppTheme.primaryPink.withAlpha(120),
                  ],
                )
              : AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isLogin ? 'Sign In' : 'Create Account',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      delay: const Duration(milliseconds: 400),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isLogin
                ? "Don't have an account? "
                : 'Already have an account? ',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
          GestureDetector(
            onTap: _toggleMode,
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: Text(
                _isLogin ? 'Sign Up' : 'Sign In',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
