import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';


class CareerRoadmapPage extends StatefulWidget {
  const CareerRoadmapPage({Key? key}) : super(key: key);

  @override
  State<CareerRoadmapPage> createState() => _CareerRoadmapPageState();
}

class _CareerRoadmapPageState extends State<CareerRoadmapPage> with TickerProviderStateMixin {
  bool _loadingAI = false;
  bool _quizStarted = false;
  bool _reviewMode = false;
  late List<Question> _questions;
  late List<int> _selectedAnswers;
  int _currentIndex = 0;

  String? _selectedRole;
  late AnimationController _timerController;
  late ValueNotifier<int> _remainingSeconds;

  final List<String> _roles = [
    'Data Analyst', 'AI Engineer', 'Machine Learning Engineer', 'Data Scientist',
    'Software Developer', 'UI/UX Designer', 'Cloud Engineer', 'DevOps Engineer',
    'Cybersecurity Analyst', 'Full Stack Developer', 'Backend Developer', 'Frontend Developer',
    'Blockchain Developer', 'Game Developer', 'AR/VR Engineer', 'Mobile App Developer',
    'Database Administrator', 'System Administrator', 'Network Engineer', 'Product Manager',
    'QA Engineer', 'IT Support Engineer', 'Automation Engineer', 'Business Analyst'
  ];

  @override
  void initState() {
    super.initState();
    _questions = [];
    _selectedAnswers = [];
  }

  Future<void> _generateQuestions() async {
    setState(() => _loadingAI = true);
    try {
final prompt = '''
      Generate 10 multiple-choice quiz questions with 4 options (A, B, C, D) each related to the IT career role: $_selectedRole.
    Each question should test real-world practical and conceptual understanding needed for that role.

    Requirements:
    1. The correct answer should appear in a random position among the 4 options.
    2. Return ONLY valid JSON in this format:
    [
    {"question":"...", "options":["...","...","...","..."], "answer":"<exact correct option text>"}
    ]
    3. Do NOT include any explanations, markdown, or text outside the JSON array.
    ''';


      final apiKey = 'YOUR_API_KEY_HERE';
      final url = Uri.parse('https://api.perplexity.ai/chat/completions');
      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            "model": "sonar-pro",
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 1200
          }));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['choices'][0]['message']['content'];
        final parsed = jsonDecode(raw);
        _questions = List<Question>.from(parsed.map((q) =>
            Question(question: q['question'], options: List<String>.from(q['options']), answer: q['answer'])));
        _selectedAnswers = List.filled(_questions.length, -1);
      } else {
        throw Exception('Failed to get questions');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loadingAI = false);
  }

  void _startQuiz() {
    _initTimer();
    setState(() => _quizStarted = true);
  }

  void _initTimer() {
    _timerController = AnimationController(vsync: this, duration: const Duration(minutes: 15));
    _remainingSeconds = ValueNotifier<int>(900);
    _timerController.addListener(() {
      final remaining = (900 * (1 - _timerController.value)).round();
      _remainingSeconds.value = remaining;
      if (_timerController.isCompleted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onTimeExpired();
        });
      }
    });
    _timerController.forward(from: 0);
  }

  void _selectAnswer(int index) {
    setState(() => _selectedAnswers[_currentIndex] = index);
  }

  void _next() {
    if (_selectedAnswers[_currentIndex] == -1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an answer')));
      return;
    }
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _reviewMode = true);
    }
  }

  void _previous() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _onTimeExpired() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Time's Up!"),
          content: const Text("Your 15 minutes have ended. Submit your answers."),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _finalSubmit();
                },
                child: const Text("Submit"))
          ],
        ));
  }

  Future<void> _finalSubmit() async {
    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] != -1 &&
          _questions[i].options[_selectedAnswers[i]] == _questions[i].answer) {
        correctCount++;
      }
    }
    double scorePercent = (correctCount / _questions.length) * 100;

    await _generateRoadmap(scorePercent);
  }

  Future<void> _generateRoadmap(double score) async {
    setState(() => _loadingAI = true);

    final answeredSummary = _questions.asMap().entries.map((e) {
      final idx = e.key;
      final q = e.value;
      final ans = _selectedAnswers[idx] == -1
          ? "No answer"
          : q.options[_selectedAnswers[idx]];
      return "Q${idx + 1}: ${q.question}\nAns: $ans";
    }).join("\n\n");

    final prompt = '''
You are an expert career counselor.
The user chose the role: $_selectedRole
Their quiz score: ${score.toStringAsFixed(1)} out of 100
Answers summary:
$answeredSummary
    Generate a detailed 5-year career roadmap for the IT career role: $_selectedRole.

    Include the following sections clearly, each with bold titles:
    1. Strength areas based on answers.
    2. Weak areas and improvement tips.
    3. Year-wise learning plan (skills, certifications, and project ideas).
    4. Soft-skill recommendations.
    5. Motivational closing line.

    Guidelines:
    - Do NOT include any Markdown, asterisks, bullets, underscores, dashes, or citation markers like [1], [2], [3].
    - Write in clean plain text, formatted for students.
    - Use clear line breaks between sections.
    - Highlight improvement areas by stating them explicitly (e.g., "Focus on improving...").
    - Include study links (as a plain list at the end, not hyperlinked).
    - Start the report with: "Your career roadmap for $_selectedRole out of 100."
    - Return the response as plain text only, no JSON, no formatting syntax.
    ''';


    String roadmap = '';
    try {
      final apiKey = 'YOUR_API_KEY_HERE';
      final url = Uri.parse('https://api.perplexity.ai/chat/completions');
      final res = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey'
          },
          body: jsonEncode({
            "model": "sonar-pro",
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 1600
          }));

      final data = jsonDecode(res.body);
      roadmap = data['choices'][0]['message']['content'];
    } catch (e) {
      roadmap = 'Error: $e';
    }

    setState(() => _loadingAI = false);

    if (!mounted) return;

    await showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text("$_selectedRole Roadmap", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                ],
              ),
              Expanded(child: SingleChildScrollView(child: Text(roadmap))),
              ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("Save as PDF"),
                  onPressed: () async => await _savePDF(roadmap, score))
            ],
          ),
        ));
  }


  Future<void> _savePDF(String text, double score) async {
    final doc = pw.Document();

    // Load a fallback font (make sure it's declared in pubspec.yaml)
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              '$_selectedRole Career Roadmap',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Paragraph(text: 'Score: ${score.toStringAsFixed(1)} / 100'),
          pw.Divider(),
          pw.Paragraph(
            text: text,
            style: pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );

    final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final file = File('${dir.path}/${_selectedRole}_roadmap.pdf');
    await file.writeAsBytes(await doc.save());
    await OpenFile.open(file.path);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Career Roadmap Quiz")),
      body: Stack(children: [
        _quizStarted ? _buildQuizUI() : _buildWelcomeScreen(),
        if (_loadingAI)
          Container(
            color: Colors.white70,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ]),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch, color: Colors.indigo, size: 80),
            const SizedBox(height: 16),
            const Text(
              "Welcome to Your Career Discovery Journey!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Select your dream IT role, take a short quiz, and let AI craft your personalized 5-year roadmap toward mastery and success.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 25),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Select Role'),
              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _selectedRole = v),
              value: _selectedRole,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Generate Quiz"),
              onPressed: _selectedRole == null ? null : () async => await _generateQuestions(),
            ),
            if (_questions.isNotEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Start Quiz"),
                onPressed: _startQuiz,
              )
          ],
        ),
      ),
    );
  }

  Widget _buildQuizUI() {
    if (_reviewMode) return _buildReview();
    final q = _questions[_currentIndex];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _remainingSeconds,
          builder: (_, secs, __) => Text("Time Left: ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}"),
        ),
        const SizedBox(height: 20),
        Text("Q${_currentIndex + 1}. ${q.question}", style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 16),
        ...q.options.asMap().entries.map((e) {
          int idx = e.key;
          String option = e.value;
          return Card(
            child: ListTile(
              title: Text(option),
              leading: Radio<int>(
                  value: idx, groupValue: _selectedAnswers[_currentIndex], onChanged: (v) => _selectAnswer(v!)),
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(children: [
          if (_currentIndex > 0)
            Expanded(child: ElevatedButton(onPressed: _previous, child: const Text("Previous"))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(onPressed: _next, child: const Text("Next")))
        ])
      ]),
    );
  }

  Widget _buildReview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Review Your Answers", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._questions.asMap().entries.map((e) {
          int idx = e.key;
          final q = e.value;
          return Card(
            child: ListTile(
              title: Text("Q${idx + 1}: ${q.question}"),
              subtitle: Text(_selectedAnswers[idx] == -1
                  ? "Not answered"
                  : q.options[_selectedAnswers[idx]]),
              trailing: ElevatedButton(
                  onPressed: () => setState(() {
                    _reviewMode = false;
                    _currentIndex = idx;
                  }),
                  child: const Text("Edit")),
            ),
          );
        }),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text("Submit & Get Roadmap"),
            onPressed: _finalSubmit)
      ],
    );
  }
}

class Question {
  final String question;
  final List<String> options;
  final String answer;
  Question({required this.question, required this.options, required this.answer});
}
