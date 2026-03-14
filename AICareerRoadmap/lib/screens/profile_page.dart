import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? firebaseUser;
  Map<String, dynamic>? userProfile;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    firebaseUser = FirebaseAuth.instance.currentUser;
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (firebaseUser == null) {
      setState(() {
        loading = false;
        userProfile = null;
      });
      return;
    }
    QuerySnapshot<Map<String, dynamic>> users;
    if (firebaseUser!.uid.isNotEmpty) {
      users = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: firebaseUser!.uid)
          .limit(1)
          .get();
    } else if (firebaseUser!.email != null) {
      users = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: firebaseUser!.email)
          .limit(1)
          .get();
    } else if (firebaseUser!.phoneNumber != null) {
      users = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: firebaseUser!.phoneNumber)
          .limit(1)
          .get();
    } else {
      setState(() {
        loading = false;
        userProfile = null;
      });
      return;
    }

    if (users.docs.isNotEmpty) {
      setState(() {
        userProfile = users.docs.first.data();
        loading = false;
      });
    } else {
      setState(() {
        userProfile = {
          "name": firebaseUser!.displayName ?? "No Name",
          "email": firebaseUser!.email ?? "",
          "phone": firebaseUser!.phoneNumber ?? "",
          "skills": "",
        };
        loading = false;
      });
    }
  }

  Future<void> _editProfileDialog() async {
    final nameCtrl = TextEditingController(text: userProfile?["name"] ?? "");
    final phoneCtrl = TextEditingController(text: userProfile?["phone"] ?? "");
    final skillsCtrl = TextEditingController(text: userProfile?["skills"] ?? "");
    final email = userProfile?["email"] ?? firebaseUser!.email ?? "";

    final formKey = GlobalKey<FormState>();

    final docQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    String? docId = docQuery.docs.isNotEmpty ? docQuery.docs.first.id : null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (val) => val == null || val.isEmpty ? "Name required" : null,
                ),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                TextFormField(
                  controller: skillsCtrl,
                  decoration: const InputDecoration(labelText: 'Skills (comma separated)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newProfile = {
                  "name": nameCtrl.text.trim(),
                  "phone": phoneCtrl.text.trim(),
                  "skills": skillsCtrl.text.trim(),
                  "email": email,
                  "uid": firebaseUser!.uid,
                };
                if (docId != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(docId)
                      .set(newProfile, SetOptions(merge: true));
                } else {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .add(newProfile);
                }
                setState(() {
                  userProfile = newProfile;
                });
                if (mounted) {
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final infoStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800);
    final valueStyle = TextStyle(color: Colors.grey.shade900);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Profile"),
        actions: [LogoutButton()],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : userProfile == null
          ? const Center(child: Text("No profile found"))
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.shade300,
                  child: const Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 20),
                _buildRow('Name:', userProfile!['name'] ?? '', infoStyle, valueStyle),
                const Divider(),
                _buildRow('Email:', userProfile!['email'] ?? '', infoStyle, valueStyle),
                const Divider(),
                _buildRow('Phone:', userProfile!['phone'] ?? '', infoStyle, valueStyle),
                const Divider(),
                _buildRow('Skills:', userProfile!['skills'] ?? '', infoStyle, valueStyle),
                const Divider(),
                const SizedBox(height: 10),
                FilledButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  onPressed: _editProfileDialog,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, TextStyle labelStyle, TextStyle valueStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Flexible(child: Text(value, style: valueStyle)),
      ],
    );
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.blue),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ),
      ],
    );
  }
}

