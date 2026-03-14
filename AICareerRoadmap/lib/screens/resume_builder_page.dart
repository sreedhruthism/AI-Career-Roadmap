import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_resume_template/flutter_resume_template.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_resume_service.dart';
import 'resume_preview_page.dart';

class ResumeField {
  final String label, key;
  final bool required;
  ResumeField(this.label, this.key, {this.required = false});
}

final List<ResumeField> basicFields = [
  ResumeField('Full Name', 'name', required: true),
  ResumeField('Address', 'address', required: true),
  ResumeField('Designation looking for', 'designation', required: true),
  ResumeField('Social Platform Link', 'social', required: false),
  ResumeField('Email', 'email', required: true),
  ResumeField('Phone Number', 'phone', required: true),
  ResumeField('Profile Summary', 'summary', required: true),
  ResumeField('Languages', 'languages', required: false),
];

class ExperienceEntry {
  final TextEditingController title = TextEditingController();
  final TextEditingController company = TextEditingController();
  final TextEditingController location = TextEditingController();
  final TextEditingController period = TextEditingController();
  final TextEditingController description = TextEditingController();
}

class SimpleEntry {
  final TextEditingController title = TextEditingController();
  final TextEditingController details = TextEditingController();
}

class ResumeBuilderPage extends StatefulWidget {
  @override
  State<ResumeBuilderPage> createState() => _ResumeBuilderPageState();
}

class _ResumeBuilderPageState extends State<ResumeBuilderPage> {
  final Map<String, TextEditingController> controllers = {
    for (var f in basicFields) f.key: TextEditingController()
  };

  final List<ExperienceEntry> experiences = [ExperienceEntry()];
  final List<SimpleEntry> projects = [SimpleEntry()];
  final List<SimpleEntry> certifications = [SimpleEntry()];

  final ImagePicker _picker = ImagePicker();
  File? profileImage;

  final List<TemplateTheme> resumeTemplates = [
    TemplateTheme.modern,
    TemplateTheme.business,
    TemplateTheme.classic,
  ];
  TemplateTheme _selectedTheme = TemplateTheme.modern;

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => profileImage = File(picked.path));
    }
  }

  bool _validateFields() {
    for (var f in basicFields) {
      if (f.required) {
        final val = controllers[f.key]?.text.trim() ?? '';
        if (val.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please fill required field: ${f.label}')),
          );
          return false;
        }
      }
    }
    final hasExperience = experiences.any((e) => e.title.text.trim().isNotEmpty);
    if (!hasExperience) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one Work Experience')),
      );
      return false;
    }
    return true;
  }

  Future<void> _autoGenerateSummary() async {
    final name = controllers['name']?.text ?? '';
    final designation = controllers['designation']?.text ?? '';
    final expTitles = experiences.map((e) => e.title.text).toList();
    final skills = (controllers['languages']?.text ?? '').split(',');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating AI summary...')),
    );

    final summary = await AIResumeService.generateSummary(
      name: name,
      designation: designation,
      experiences: expTitles,
      skills: skills,
    );

    if (summary != null && summary.isNotEmpty) {
      setState(() {
        controllers['summary']?.text = summary;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Summary Added!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Generation Failed.')),
      );
    }
  }

  void _previewAndGeneratePdf() {
    if (!_validateFields()) return;

    final experienceData = experiences
        .where((e) => e.title.text.trim().isNotEmpty)
        .map((e) => ExperienceData(
      experienceTitle: e.title.text,
      experiencePlace: e.company.text,
      experienceLocation: e.location.text,
      experiencePeriod: e.period.text,
      experienceDescription: e.description.text,
    ))
        .toList();

    final educationData = <Education>[
      Education("Bachelor of Technology", "ABC University"),
      Education("High School", "XYZ School"),
    ];

    final templateData = TemplateData(
      fullName: controllers['name']?.text ?? '',
      currentPosition: controllers['designation']?.text ?? '',
      street: controllers['address']?.text ?? '',
      address: controllers['address']?.text ?? '',
      email: controllers['email']?.text ?? '',
      phoneNumber: controllers['phone']?.text ?? '',
      bio: controllers['summary']?.text ?? '',
      experience: experienceData,
      educationDetails: educationData,
      languages: [Language(controllers['languages']?.text ?? '', 5)],
      hobbies: [],
      image: profileImage != null ? profileImage!.path : '',
      backgroundImage: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResumePreviewPage(
          templateData: templateData,
          selectedTheme: _selectedTheme,
        ),
      ),
    );
  }

  Widget _buildBasicField(ResumeField f) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controllers[f.key],
        maxLines: f.key == 'summary' ? 4 : 1,
        decoration: InputDecoration(
          labelText: f.label + (f.required ? ' *' : ''),
          border: const OutlineInputBorder(),
          suffixIcon: f.key == 'summary'
              ? IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: _autoGenerateSummary,
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildExperienceCard(int idx) {
    final e = experiences[idx];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                  controller: e.title,
                  decoration: const InputDecoration(labelText: 'Job Title')),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => setState(() => experiences.removeAt(idx)),
            ),
          ]),
          TextField(
              controller: e.company,
              decoration: const InputDecoration(labelText: 'Company')),
          TextField(
              controller: e.location,
              decoration: const InputDecoration(labelText: 'Location')),
          TextField(
              controller: e.period,
              decoration: const InputDecoration(labelText: 'Period')),
          TextField(
              controller: e.description,
              decoration: const InputDecoration(labelText: 'Description')),
        ]),
      ),
    );
  }

  Widget _buildSimpleCard(SimpleEntry s, VoidCallback onRemove) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: s.title,
                    decoration: const InputDecoration(labelText: 'Title'))),
            IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onRemove)
          ]),
          TextField(
              controller: s.details,
              decoration: const InputDecoration(labelText: 'Details'))
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume Builder')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [
                  GestureDetector(
                    onTap: _pickProfileImage,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: profileImage != null
                          ? FileImage(profileImage!)
                          : const AssetImage('assets/profile_placeholder.png')
                      as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...basicFields.map(_buildBasicField),
                  const Divider(),
                  const Text("Work Experience"),
                  Column(
                    children: List.generate(
                      experiences.length,
                          (i) => _buildExperienceCard(i),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => experiences.add(ExperienceEntry())),
                    child: const Text("Add Experience"),
                  ),
                  const Divider(),
                  const Text("Projects"),
                  Column(
                    children: List.generate(
                      projects.length,
                          (i) => _buildSimpleCard(
                        projects[i],
                            () => setState(() => projects.removeAt(i)),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => projects.add(SimpleEntry())),
                    child: const Text("Add Project"),
                  ),
                  const Divider(),
                  const Text("Certifications"),
                  Column(
                    children: List.generate(
                      certifications.length,
                          (i) => _buildSimpleCard(
                        certifications[i],
                            () => setState(() => certifications.removeAt(i)),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => certifications.add(SimpleEntry())),
                    child: const Text("Add Certification"),
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 10,
                    children: resumeTemplates
                        .map(
                          (t) => ChoiceChip(
                        label: Text(t.toString().split('.').last),
                        selected: _selectedTheme == t,
                        onSelected: (_) =>
                            setState(() => _selectedTheme = t),
                      ),
                    )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.preview),
                    label: const Text("Preview & Generate PDF"),
                    onPressed: _previewAndGeneratePdf,
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
