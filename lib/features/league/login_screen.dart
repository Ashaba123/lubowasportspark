import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/auth/auth_repository.dart';
import 'package:lubowa_sports_park/core/auth/token_storage.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/core/utils/app_connectivity.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/features/league/signup_screen.dart';

/// JWT login. On success stores token and pops with true.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  AuthRepository? _authRepo;
  TokenStorage? _tokenStorage;
  GoogleSignIn? _googleSignIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authRepo ??= AuthRepository(apiClient: context.read<ApiClient>());
    _tokenStorage ??= context.read<TokenStorage>();
    _googleSignIn ??= GoogleSignIn(
      scopes: const <String>['email', 'profile'],
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    if (!await hasNetworkConnectivity()) {
      setState(() => _error = userFriendlyApiErrorMessage(NoConnectivityException()));
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final token = await _authRepo!.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
      await _tokenStorage!.setToken(token);
      if (!mounted) return;
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    if (!await hasNetworkConnectivity()) {
      setState(() => _error = userFriendlyApiErrorMessage(NoConnectivityException()));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return;
      }
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Google sign-in did not return a valid token.';
        });
        return;
      }
      final result = await _authRepo!.loginWithGoogle(
        idToken,
        displayName: account.displayName,
      );
      if (result.token.isNotEmpty) {
        await _tokenStorage!.setToken(result.token);
      }
      if (!mounted) return;
      Navigator.of(context).pop<bool>(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                             color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.emoji_events, color: colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Login to manage your league',
                              style: textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ask the Lubowa Sports Park staff at the counter to create a user account for you. '
                        'Use that username and password here to create leagues, add teams and players, and update fixtures each week.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText: 'This is the WordPress username the staff created for you',
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const FootballLoader(size: 22)
                    : const Text('Log in'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loading ? null : _loginWithGoogle,
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
              Center(
                child: Column(
                  children: [
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              final bool? created = await navigator.push<bool>(
                                MaterialPageRoute(builder: (_) => const SignupScreen()),
                              );
                              if (created == true && mounted) {
                                navigator.pop(true);
                              }
                            },
                      child: const Text(
                        'New to Lubowa app? Create an account.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final uri = Uri.parse('${AppConstants.websiteUrl}/contact');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text(
                        'Prefer staff to set up your access? Contact us on the website.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
