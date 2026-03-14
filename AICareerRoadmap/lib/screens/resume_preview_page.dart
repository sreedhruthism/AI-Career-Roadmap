import 'package:flutter/material.dart';
import 'package:flutter_resume_template/flutter_resume_template.dart';
import '../services/pdf_handler.dart' as my_pdf;

class ResumePreviewPage extends StatefulWidget {
  final TemplateData templateData;
  final TemplateTheme selectedTheme;

  const ResumePreviewPage({
    Key? key,
    required this.templateData,
    required this.selectedTheme,
  }) : super(key: key);

  @override
  State<ResumePreviewPage> createState() => _ResumePreviewPageState();
}

class _ResumePreviewPageState extends State<ResumePreviewPage> {
  final GlobalKey _resumeKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Preview Resume")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              RepaintBoundary(
                key: _resumeKey,
                child: FlutterResumeTemplate(
                  data: widget.templateData,
                  templateTheme: widget.selectedTheme,
                  // mode removed for flutter_resume_template 1.2.1
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Save as PDF"),
                onPressed: () async {
                  try {
                    await my_pdf.PdfHandler().createResume(_resumeKey);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Resume saved as PDF!")),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error saving PDF: $e")),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
