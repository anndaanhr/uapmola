import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF86D2A)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return HomeScreen(user: user);
        }

        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLogin = true;
  bool _obscure = true;
  bool _rememberMe = false;
  bool _submitting = false;
  bool _socialLoading = false;
  bool _googleInitialized = false;
  String? _errorText;

  Color get _accent => const Color(0xFFF86D2A);
  OutlineInputBorder get _inputBorder => OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.circular(12),
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Email dan password harus diisi.');
      return;
    }
    if (!_isLogin && password != confirm) {
      setState(() => _errorText = 'Konfirmasi password tidak sama.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? 'Terjadi kesalahan.');
    } catch (_) {
      setState(() => _errorText = 'Terjadi kesalahan.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = 'Masukkan email untuk reset password.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Email reset dikirim.')));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? 'Gagal kirim reset.');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _socialLoading = true;
      _errorText = null;
    });

    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize();
        _googleInitialized = true;
      }

      final account = await GoogleSignIn.instance.authenticate();
      final googleAuth = account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _errorText = e.description ?? 'Login Google gagal.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? 'Login Google gagal.');
    } catch (_) {
      setState(() => _errorText = 'Login Google gagal, coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _socialLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _accent.withValues(alpha: 0.15),
                    child: Icon(Icons.lock_outline, color: _accent, size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Create Account',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'Sign in to continue to your account'
                        : 'Register to start your journey',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _InputWrapper(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        border: _inputBorder,
                        prefixIcon: const Icon(Icons.email_outlined),
                        hintText: 'Email Address',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InputWrapper(
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        border: _inputBorder,
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 12),
                    _InputWrapper(
                      child: TextField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          border: _inputBorder,
                          prefixIcon: const Icon(Icons.lock_outline),
                          hintText: 'Confirm Password',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: _accent,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                      ),
                      const Text('Remember me'),
                      const Spacer(),
                      TextButton(
                        onPressed: _submitting ? null : _resetPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: _accent,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Forgot Password?'),
                      ),
                    ],
                  ),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        _errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_submitting || _socialLoading)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(_isLogin ? 'Sign In' : 'Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Or continue with',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          label: 'Google',
                          icon: const Icon(Icons.g_mobiledata),
                          onPressed: (_submitting || _socialLoading)
                              ? null
                              : _signInWithGoogle,
                          loading: _socialLoading,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SocialButton(
                          label: 'Apple',
                          icon: const Icon(Icons.apple),
                          onPressed: (_submitting || _socialLoading)
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Apple login belum diatur.',
                                      ),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin
                            ? "Don't have an account?"
                            : 'Sudah punya akun?',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _errorText = null;
                                });
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: _accent,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(_isLogin ? 'Sign Up' : 'Sign In'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputWrapper extends StatelessWidget {
  const _InputWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [icon, const SizedBox(width: 8), Text(label)],
            ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await GoogleSignIn.instance.signOut();
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, size: 64),
              const SizedBox(height: 12),
              Text(
                'Sudah login sebagai:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? 'Tidak ada email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'UID: ${user.uid}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
