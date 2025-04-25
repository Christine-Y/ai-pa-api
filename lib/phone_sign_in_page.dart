import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';

class PhoneSignInPage extends StatefulWidget {
  const PhoneSignInPage({super.key});

  @override
  State<PhoneSignInPage> createState() => _PhoneSignInPageState();
}

class _PhoneSignInPageState extends State<PhoneSignInPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _rateLimitTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 0;
  }

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _resetRateLimit() {
    if (_rateLimitTimer != null) {
      _rateLimitTimer!.cancel();
      _rateLimitTimer = null;
    }
    setState(() {
      _remainingSeconds = 0;
      _errorMessage = null;
      _isLoading = false;
    });
  }

  void _startRateLimitTimer() {
    if (_rateLimitTimer != null) {
      _rateLimitTimer!.cancel();
    }
    _remainingSeconds = 3600; // 1 hour in seconds
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
          _rateLimitTimer = null;
          _errorMessage = null;
        }
      });
    });
  }

  String _formatPhoneNumber(String phone) {
    // Remove any non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // If the number starts with 0, replace it with +44
    if (digits.startsWith('0')) {
      digits = '+44' + digits.substring(1);
    }
    
    // If the number doesn't start with +, add it
    if (!digits.startsWith('+')) {
      digits = '+' + digits;
    }
    
    return digits;
  }

  void _resetState() {
    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _verificationId = null;
      _codeController.clear();
    });
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        setState(() {
          _errorMessage = 'Could not open the subscription page';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error opening the subscription page: $e';
      });
    }
  }

  Future<void> _verifyPhone() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a phone number';
      });
      return;
    }

    if (_remainingSeconds > 0) {
      setState(() {
        _errorMessage = 'Please wait ${_remainingSeconds ~/ 60} minutes before trying again';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _verificationId = null;
      _codeController.clear();
    });

    try {
      final formattedPhone = _formatPhoneNumber(_phoneController.text);
      
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
          } catch (e) {
            setState(() {
              _errorMessage = 'Verification completed but sign in failed: $e';
              _isLoading = false;
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          String userFriendlyMessage;
          switch (e.code) {
            case 'invalid-phone-number':
              userFriendlyMessage = 'Please enter a valid phone number';
              break;
            case 'too-many-requests':
              _startRateLimitTimer();
              userFriendlyMessage = 'Too many attempts. Please try again in 1 hour';
              break;
            case 'user-not-found':
            case 'recaptcha-not-enabled':
            case 'recaptcha-check-failed':
            case 'recaptcha-invalid-action':
            case 'recaptcha-invalid-sitekey':
            case 'recaptcha-invalid-token':
            case 'recaptcha-invalid-type':
            case 'recaptcha-invalid-version':
              userFriendlyMessage = 'This number is not subscribed to the service. Please try again or subscribe using the link below';
              break;
            default:
              userFriendlyMessage = 'This number is not subscribed to the service. Please try again or subscribe using the link below';
          }
          setState(() {
            _errorMessage = userFriendlyMessage;
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
            _errorMessage = 'SMS code timeout. Please try again';
          });
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again';
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithCode() async {
    if (_verificationId == null) {
      setState(() {
        _errorMessage = 'Please request a verification code first';
      });
      return;
    }

    if (_codeController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid verification code. Please try again';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to My PA'),
        actions: [
          if (_remainingSeconds > 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetRateLimit,
              tooltip: 'Reset rate limit',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the monitored phone number',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number (e.g., +44 7979 XXX XXX)',
              ),
              keyboardType: TextInputType.phone,
              onChanged: (_) => _resetState(),
              onSubmitted: (_) => _verifyPhone(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading || _remainingSeconds > 0 ? null : _verifyPhone,
              child: _isLoading 
                ? const CircularProgressIndicator()
                : _remainingSeconds > 0
                  ? Text('Wait ${_remainingSeconds ~/ 60} minutes')
                  : const Text('Send Code'),
            ),
            if (_verificationId != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'SMS Code',
                  hintText: 'Enter the 6-digit code',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (_) => setState(() => _errorMessage = null),
                onSubmitted: (_) => _signInWithCode(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithCode,
                child: _isLoading 
                  ? const CircularProgressIndicator()
                  : const Text('Verify and Sign In'),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              if (_errorMessage!.contains('link below'))
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.red),
                    children: [
                      const TextSpan(
                        text: 'This number is not subscribed to the service\n\n'
                            'Either enter the correct number,\n        or subscribe at:\n\n'),
                      TextSpan(
                        text: 'https://bt.com',
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _launchUrl('https://bt.com'),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
