import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';

// --------- JOB MODEL ---------
class Job {
  final String title;
  final String descriptionHtml;
  final String jobType;
  final String jobKey;
  final String jobUrl;

  Job({
    required this.title,
    this.descriptionHtml = '',
    this.jobType = '',
    this.jobKey = '',
    this.jobUrl = '',
  });

  factory Job.fromRemotiveJson(Map<String, dynamic> json) {
    return Job(
      title: json['title'] ?? '',
      descriptionHtml: json['description'] ?? '',
      jobType: json['job_type'] ?? '',
      jobKey: json['id'].toString(),
      jobUrl: json['url'] ?? '',
    );
  }
}

// --------- PERPLEXITY SERVICE (unchanged) ---------
class PerplexityService {
  final String apiUrl = 'https://api.perplexity.ai/chat/completions';
  final String apiKey = 'YOUR_API_KEY_HERE'; // Your actual Perplexity API key

  Future<String> sendPrompt(String prompt) async {
    final body = jsonEncode({
      "model": "sonar",
      "messages": [
        {
          "role": "system",
          "content":
          "You are CareerBot, a helpful and knowledgeable career navigation assistant. Only answer questions related to careers, jobs, job search strategies, resume building, interview tips, professional growth, and related topics. If the user asks something off-topic such as a greeting or random fact, politely steer the conversation back to career guidance and offer to help with career-related questions."
        },
        {"role": "user", "content": prompt}
      ]
    });

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json"
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to retrieve response: ${response.statusCode}');
    }
  }
}

// --------- REMOTIVE JOBS SERVICE ---------
class RemotiveJobsService {
  final String apiUrl = 'https://remotive.com/api/remote-jobs';

  Future<List<Job>> fetchJobs({String? keyword}) async {
    try {
      final q = keyword != null && keyword.trim().isNotEmpty ? '?search=${Uri.encodeQueryComponent(keyword)}' : '';
      final url = Uri.parse(apiUrl + q);
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allJobs = data['jobs'] ?? [];
        // Filter for Indian location in candidate_required_location
        final indiaJobs = allJobs.where((job) {
          final loc = (job['candidate_required_location'] ?? '').toString().toLowerCase();
          return loc.contains('india');
        }).toList();

        return indiaJobs.map((j) => Job.fromRemotiveJson(j)).toList();
      } else {
        print('Remotive API error: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception fetching Remotive jobs: $e');
      return [];
    }
  }
}

// --------- DASHBOARD PAGE ---------
class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final _user = FirebaseAuth.instance.currentUser!;
  File? _profileImage;
  bool showChat = false, _sending = false, aiBlocked = false;
  final TextEditingController _chatController = TextEditingController();
  List<_ChatMessage> _messages = [];
  late AnimationController _fadeController;

  int appliedCount = 0, responsesCount = 0;
  List<Job> jobs = [];
  late String welcomeMsg;

  List<String> allLocations = ['All Locations'];
  String selectedLocation = 'All Locations';

  final PerplexityService service = PerplexityService();
  final RemotiveJobsService remotiveJobsService = RemotiveJobsService();

  final List<String> dailyGreetings = [
    "Let's make today awesome, {name}!",
    "Welcome back, {name}! Your career adventure continues!",
    "Hi, {name}! Ready for new opportunities?",
    "Good day, {name}! Let's reach new heights.",
    "Glad to see you again, {name}!",
    "Hey, {name}, let's shine bright today!",
    "Seize the day, {name}!",
    "Thanks for coming back!",
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _loadProfileImage();
    _fetchJobsAndStats();
    _setWelcomeMessage();
  }

  void _setWelcomeMessage() {
    final name = _user.displayName ?? _user.email?.split('@').first ?? 'User';
    final now = DateTime.now();
    final rng = Random(now.year * 10000 + now.month * 100 + now.day);
    final tmpl = dailyGreetings[rng.nextInt(dailyGreetings.length)];
    setState(() {
      welcomeMsg = tmpl.replaceAll("{name}", name);
    });
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');
    if (path != null && File(path).existsSync()) {
      setState(() => _profileImage = File(path));
    }
  }

  Future<void> _fetchJobsAndStats() async {
    try {
      final fetchedJobs = await remotiveJobsService.fetchJobs(keyword: "developer");
      // Extract unique location strings for filter
      final locSet = <String>{'All Locations'};
      for (final job in fetchedJobs) {
        final loc = _extractLocationFromDescription(job.descriptionHtml);
        if (loc.isNotEmpty) locSet.add(loc);
      }
      setState(() {
        jobs = fetchedJobs;
        allLocations = locSet.toList()..sort();
      });
    } catch (e) {
      print('Exception fetching jobs: $e');
    }
  }

  String _extractLocationFromDescription(String description) {
    if (description.isEmpty) return '';
    final regex = RegExp(r'Location[:\-]?\s*([a-zA-Z ,]+)', caseSensitive: false);
    final cleanString = description.replaceAll(RegExp(r'<[^>]*>'), '');
    final match = regex.firstMatch(cleanString);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!.trim();
    }
    return '';
  }

  List<Job> get filteredJobs {
    if (selectedLocation == 'All Locations') return jobs;
    return jobs.where((j) {
      final loc = _extractLocationFromDescription(j.descriptionHtml).toLowerCase();
      return loc == selectedLocation.toLowerCase();
    }).toList();
  }

  List<Job> get karnatakaJobs {
    return jobs.where((j) {
      final loc = _extractLocationFromDescription(j.descriptionHtml).toLowerCase();
      return loc.contains('karnataka') || loc.contains('bangalore');
    }).toList();
  }

  void _openChat() {
    setState(() => showChat = true);
    _fadeController.forward(from: 0);
  }

  void _closeChat() {
    _fadeController.reverse().then((_) => setState(() => showChat = false));
  }

  Future<void> _handleSend() async {
    if (aiBlocked) {
      setState(() {
        _messages.add(_ChatMessage("Too many requests to AI: Please wait a moment.", isUser: false));
      });
      return;
    }
    final prompt = _chatController.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(prompt, isUser: true));
      _chatController.clear();
      _sending = true;
    });
    try {
      final reply = await service.sendPrompt(prompt);
      setState(() {
        _messages.add(_ChatMessage(reply, isUser: false));
      });
    } catch (e) {
      if (e.toString().contains('429')) {
        aiBlocked = true;
        Future.delayed(const Duration(minutes: 1), () => aiBlocked = false);
        setState(() {
          _messages.add(_ChatMessage("AI limit reached, please try again later.", isUser: false));
        });
      } else {
        setState(() {
          _messages.add(_ChatMessage("Error: $e", isUser: false));
        });
      }
    }
    setState(() {
      _sending = false;
    });
  }

  void _showContactPopup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Contact Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(leading: Icon(Icons.mail), title: Text('support@careerai.com')),
            ListTile(leading: Icon(Icons.phone), title: Text('+91 98765 43210')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          startDegreeOffset: 240,
          sectionsSpace: 4,
          centerSpaceRadius: 45,
          sections: [
            PieChartSectionData(value: appliedCount.toDouble(), color: Colors.blue.shade900, radius: 38, showTitle: false),
            PieChartSectionData(value: responsesCount.toDouble(), color: Colors.blue.shade500, radius: 38, showTitle: false),
            PieChartSectionData(value: jobs.length.toDouble(), color: Colors.blue.shade200, radius: 38, showTitle: false),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.blue.shade100)),
      child: SizedBox(
        width: 100,
        height: 70,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard('Applied', appliedCount),
        _buildStatCard('Responses', responsesCount),
        _buildStatCard('Jobs', jobs.length),
      ],
    );
  }

  Widget _buildDrawer(String displayName) {
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(displayName),
            accountEmail: Text(_user.email ?? ''),
            currentAccountPicture: GestureDetector(
              onTap: _pickProfileImage,
              child: CircleAvatar(
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null ? const Icon(Icons.person, size: 40) : null,
              ),
            ),
          ),
          _drawerTile('Course Roadmap', Icons.quiz, '/career_roadmap'),
          _drawerTile('Career Roadmap', Icons.timeline, '/course_roadmap'),
          _drawerTile('Job Openings', Icons.work, '/job_openings'),
          _drawerTile('Resume Builder', Icons.description, '/resume_builder'),
          _drawerTile('Update Profile', Icons.person, '/profile'),
          const Divider(),
          ListTile(leading: const Icon(Icons.info_outline), title: const Text('Contact Info'), onTap: _showContactPopup),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: _logout),
        ],
      ),
    );
  }

  ListTile _drawerTile(String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }

  Future<void> _pickProfileImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      setState(() {
        _profileImage = file;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', file.path);
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user.displayName ?? _user.email?.split('@').first ?? 'User';

    return Stack(children: [
      Scaffold(
        appBar: AppBar(title: Text('Career Dashboard')),
        drawer: _buildDrawer(displayName),
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFF5F9FE),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      welcomeMsg,
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.blue.shade800),
                    ),
                    const SizedBox(height: 18),
                    Center(child: _buildPieChart()),
                    const SizedBox(height: 8),
                    _buildStatsRow(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 10, top: 28, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recommended Jobs', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: selectedLocation,
                      items: allLocations.map((location) {
                        return DropdownMenuItem(
                          value: location,
                          child: Text(location),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedLocation = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              RecommendedJobsWidget(jobs: filteredJobs),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 10, top: 24, bottom: 0),
                child: const Text('Jobs from Karnataka / Bangalore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              RecommendedJobsWidget(jobs: karnatakaJobs),
              const SizedBox(height: 40),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openChat,
          child: const Icon(Icons.chat_bubble_outline),
          tooltip: 'CareerBot',
        ),
      ),
      if (showChat)
        Positioned(
          bottom: 80,
          right: 20,
          child: FadeTransition(
            opacity: _fadeController,
            child: _ChatPanel(
              messages: _messages,
              controller: _chatController,
              onSend: _handleSend,
              onClose: _closeChat,
              sending: _sending,
            ),
          ),
        ),
    ]);
  }
}

class RecommendedJobsWidget extends StatelessWidget {
  final List<Job> jobs;
  const RecommendedJobsWidget({Key? key, required this.jobs}) : super(key: key);

  void _launchURL(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No application link provided.')));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunch(uri.toString())) {
      await launch(uri.toString());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch URL.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, idx) {
        final job = jobs[idx];
        return Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE6ECFC)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.work_outline, color: Color(0xFF3372F7), size: 26),
              ),
              title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (job.jobType.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Type: ${job.jobType}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ),
                  if (job.descriptionHtml.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text('See job details for more info', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    ),
                ],
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2F6FF),
                  foregroundColor: const Color(0xFF3772F7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _launchURL(context, job.jobUrl),
                child: const Text('Apply'),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Chat message model
class _ChatMessage {
  final String message;
  final bool isUser;
  _ChatMessage(this.message, {this.isUser = false});
}

// Chat panel widget
class _ChatPanel extends StatelessWidget {
  final List<_ChatMessage> messages;
  final TextEditingController controller;
  final VoidCallback onSend, onClose;
  final bool sending;

  const _ChatPanel({
    Key? key,
    required this.messages,
    required this.controller,
    required this.onSend,
    required this.onClose,
    required this.sending,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 340,
        height: 400,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[messages.length - 1 - i];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: msg.isUser ? Colors.blue[50] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg.message),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask CareerBot…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSend(),
                    enabled: !sending,
                  ),
                ),
                const SizedBox(width: 6),
                sending
                    ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: onSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}