import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_page.dart';

class RecommendedJobsWidget extends StatelessWidget {
  final List<Job> jobs;
  final VoidCallback onApply; // <-- new

  const RecommendedJobsWidget({Key? key, required this.jobs,required this.onApply,}) : super(key: key);

  void _launchJobUrl(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No application link provided for this job.'))
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open job URL.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: jobs.length,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (_, idx) {
        final j = jobs[idx];
        return Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color(0xFFE6ECFC)),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFFF2F6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.work_outline, color: Color(0xFF3372F7), size: 26),
              ),
              title: Text(j.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (j.jobType.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('Type: ${j.jobType}', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    ),
                  if (j.descriptionHtml.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3.0),
                      child: Text('See details in description', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    ),
                ],
              ),
              trailing: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Color(0xFFF2F6FF)),
                  elevation: MaterialStateProperty.all(0),
                  foregroundColor: MaterialStateProperty.all(Color(0xFF3772F7)),
                  textStyle: MaterialStateProperty.all(TextStyle(fontWeight: FontWeight.bold)),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                onPressed: () => _launchJobUrl(context, j.jobUrl),
                child: Text('Apply'),
              ),
            ),
          ),
        );
      },
    );
  }
}
