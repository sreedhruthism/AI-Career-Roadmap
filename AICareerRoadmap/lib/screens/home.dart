import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  void _showContactInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Contact Info", style: TextStyle(color: Colors.blue[900])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email, color: Colors.blue),
              title: Text("support@careernav.com"),
            ),
            ListTile(
              leading: Icon(Icons.phone, color: Colors.blue),
              title: Text("+91 12345 67890"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Career Navigator"),
        actions: [
          IconButton(
              icon: const Icon(Icons.contact_support_outlined),
              tooltip: "Contact info",
              onPressed: () => _showContactInfo(context)
          ),
          _LogoutButton(),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text(
              'Welcome to your personalized AI Career Roadmap dashboard.\nHere you\'ll find tailored career advice, essential skills, and top job opportunities.',
              style: TextStyle(fontSize: 18, color: Colors.grey[900]),
            ),
            const SizedBox(height: 36),

            _DashboardCard(
              color: Colors.blue[50]!,
              icon: Icons.quiz,
              title: "Career Roadmap Quiz",
              subtitle: "Get personalized career suggestions",
              onTap: () => Navigator.pushNamed(context, '/career_roadmap'),
            ),
            const SizedBox(height: 18),
            _DashboardCard(
              color: Colors.blue[100]!,
              icon: Icons.work,
              title: "Job Openings",
              subtitle: "See jobs based on your profile & interests",
              onTap: () => Navigator.pushNamed(context, '/job_openings'),
            ),
            const SizedBox(height: 18),
            _DashboardCard(
              color: Colors.blue[50]!,
              icon: Icons.description,
              title: "AI Resume Builder",
              subtitle: "Generate a professional resume",
              onTap: () => Navigator.pushNamed(context, '/resume_builder'),
            ),
            const SizedBox(height: 18),
            _DashboardCard(
              color: Colors.blue[100]!,
              icon: Icons.person,
              title: "Profile",
              subtitle: "Update your personal info & skills",
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// Professional dashboard feature card
class _DashboardCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    elevation: 2,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.blue[700]),
            const SizedBox(width: 20),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[900])),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.blue),
          ],
        ),
      ),
    ),
  );
}

// Reuse the pop-up menu logout button
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.logout, color: Colors.blue),
            title: Text('Logout'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
            },
          ),
        ),
      ],
    );
  }
}
