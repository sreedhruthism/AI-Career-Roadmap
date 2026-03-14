import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  String error = '';
  bool loading = false;

  bool _isEmail(String input) {
    final emailRegEx = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegEx.hasMatch(input.trim());
  }

  Future<void> _registerUser() async {
    setState(() {
      error = '';
      loading = true;
    });
    final email = emailCtrl.text.trim();
    final password = pwdCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty || phone.isEmpty) {
      setState(() {
        error = 'Please fill all fields';
        loading = false;
      });
      return;
    }
    if (!_isEmail(email)) {
      setState(() {
        error = 'Please enter a valid email address.';
        loading = false;
      });
      return;
    }
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);

      // Update the display name
      await cred.user?.updateDisplayName(name);

      // Save phone number in Firestore or custom user claim here
      // Example: You need to have Firestore set up to save user profile with phone
      // await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
      //   'phone': phone,
      //   'name': name,
      //   'email': email,
      // });

      // Send verification email
      await cred.user?.sendEmailVerification();

      // Optionally sign-out after registration to enforce verification before login
      // await FirebaseAuth.instance.signOut();

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Registration Successful"),
            content: const Text(
                'Check your email for a verification link. Sign in after verifying your address.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() {
          error = 'An account already exists for that email.';
        });
      } else if (e.code == 'weak-password') {
        setState(() {
          error = 'Password should be at least 6 characters.';
        });
      } else if (e.code == 'invalid-email') {
        setState(() {
          error = 'The email address is badly formatted.';
        });
      } else {
        setState(() {
          error = 'Registration failed: ${e.message}';
        });
      }
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Card(
          elevation: 7,
          margin: const EdgeInsets.all(0),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Create Account",
                    style: TextStyle(fontSize: 22, color: Colors.blue[900], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pwdCtrl,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    child: loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Register'),
                    onPressed: loading ? null : _registerUser,
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(error, style: const TextStyle(color: Colors.red)),
                    ),
                  TextButton(
                    child: const Text("Already have an account? Sign in", style: TextStyle(color: Colors.blue)),
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
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
