import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// --------- JOB MODEL ---------
class Job {
  final String title;
  final String companyName;
  final String salary;
  final String url;
  final String location;

  Job({
    required this.title,
    required this.companyName,
    required this.salary,
    required this.url,
    required this.location,
  });

  factory Job.fromRemotiveJson(Map<String, dynamic> json) {
    return Job(
      title: json['title'] ?? 'Untitled Job',
      companyName: json['company_name'] ?? 'Unknown Company',
      salary: json['salary'] ?? 'Not Disclosed',
      url: json['url'] ?? '',
      location: json['candidate_required_location'] ?? 'Remote',
    );
  }
}

// --------- REMOTIVE JOBS SERVICE ---------
class RemotiveJobsService {
  final String apiUrl = 'https://remotive.com/api/remote-jobs';

  Future<List<Job>> fetchJobs({String? keyword}) async {
    try {
      final q = keyword != null && keyword.trim().isNotEmpty
          ? '?search=${Uri.encodeQueryComponent(keyword)}'
          : '';
      final url = Uri.parse(apiUrl + q);
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allJobs = data['jobs'] ?? [];

        // Filter for Indian location in candidate_required_location
        final indiaJobs = allJobs.where((job) {
          final loc =
          (job['candidate_required_location'] ?? '').toString().toLowerCase();
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

// --------- MAIN JOB PAGE ---------
class JobOpeningsPage extends StatefulWidget {
  const JobOpeningsPage({Key? key}) : super(key: key);

  @override
  State<JobOpeningsPage> createState() => _JobOpeningsPageState();
}


class _JobOpeningsPageState extends State<JobOpeningsPage> {
  final RemotiveJobsService _jobService = RemotiveJobsService();
  List<Job> _jobs = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs({String? keyword}) async {
    setState(() => _loading = true);
    final jobs = await _jobService.fetchJobs(keyword: keyword);
    setState(() {
      _jobs = jobs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Top Job Openings"),
        actions: [_LogoutButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search jobs (e.g., Cloud Engineer, Python)...",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _loadJobs(keyword: _searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (value) => _loadJobs(keyword: value),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                ? const Center(child: Text("No jobs found for India."))
                : RefreshIndicator(
              onRefresh: () => _loadJobs(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _jobs.length,
                itemBuilder: (_, i) {
                  final job = _jobs[i];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.work_outline,
                          color: Colors.blueAccent),
                      title: Text(
                        job.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${job.companyName}\n${job.location}\n${job.salary}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      isThreeLine: true,
                      trailing: TextButton(
                        child: const Text("Apply",
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                        onPressed: () =>
                            _launchURL(context, job.url),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _launchURL(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Open Job Link"),
        content: Text('Would launch: $url'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }
}

// --------- LOGOUT MENU ---------
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.blue),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (r) => false);
            },
          ),
        ),
      ],
    );
  }
}
