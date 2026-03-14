import 'package:flutter/material.dart';

class RoadmapResultPage extends StatelessWidget {
  final String designation;
  RoadmapResultPage({this.designation = "Software Developer"}); // Default for example

  String getResultText() {
    switch (designation) {
      case "Software Developer":
        return "As a Software Developer, you design, develop, test, and deploy software systems or applications. You'll work with teams, write clean and scalable code, participate in code reviews, and continuously learn new programming languages, tools, and best practices to stay updated with industry trends.";
      case "UI/UX Designer":
        return "A UI/UX Designer focuses on the visual and functional aspects of digital products. Your role is to ensure user satisfaction by improving usability, interaction, and aesthetics of apps and websites. You'll conduct user research, create wireframes and prototypes, and collaborate with developers.";
      case "Data Analyst":
        return "As a Data Analyst, you'll transform raw data into meaningful insights. You'll clean and analyze large datasets, use visualization tools, and help organizations make data-driven decisions. This role involves statistics, storytelling with data, and strong technical tool usage.";
      case "IT Support Engineer":
        return "As an IT Support Engineer, you provide technical assistance to users, troubleshoot hardware and software problems, and ensure system availability. You'll work with networking, security, and system tools to maintain smooth IT operations and improve the user experience.";
      default:
        return "You’re on a dynamic IT path. Stay curious, keep exploring interdisciplinary areas, and use your passion to craft a career with purpose, flexibility, and constant learning.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your Career Roadmap"),
        actions: [_LogoutButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag, size: 44, color: Colors.blue[800]),
                SizedBox(height: 20),
                Text(
                  "Suggested Track: $designation",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  textAlign: TextAlign.center,
                ),
                Divider(),
                SizedBox(height: 12),
                Text(
                  getResultText(),
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
