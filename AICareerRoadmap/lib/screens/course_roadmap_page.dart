import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

// 💡 Define the base URL for the Node.js server
// Using 10.0.2.2 for Android emulator to talk to localhost
const String kBaseUrl = 'http://10.0.2.2:5000';
const String kApiEndpoint = '/api/kcet_dataset'; // Correct endpoint

class CourseRoadmapPage extends StatefulWidget {
  const CourseRoadmapPage({Key? key}) : super(key: key);

  @override
  State<CourseRoadmapPage> createState() => _CourseRoadmapPageState();
}

class _CourseRoadmapPageState extends State<CourseRoadmapPage> with TickerProviderStateMixin {
  late Future<List<Question>> _questionsFuture;
  late List<int> _selectedAnswers;
  int _currentIndex = 0;
  bool _loadingAI = false;
  bool _reviewMode = false;
  bool _quizStarted = false;

  late AnimationController _timerController;
  late ValueNotifier<int> _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _questionsFuture = _loadRandomQuestions();
    _selectedAnswers = [];
    _currentIndex = 0;
    _loadingAI = false;
    _reviewMode = false;
  }

  void _startQuiz() {
    _initQuiz();
    setState(() { _quizStarted = true; });
  }

  void _initQuiz() {
    _questionsFuture = _loadRandomQuestions();
    _selectedAnswers = List.filled(30, -1); // Initialize to 30 to avoid RangeError before data loads
    _currentIndex = 0;
    _loadingAI = false;
    _reviewMode = false;

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 30),
    );
    _remainingSeconds = ValueNotifier<int>(1800);

    _timerController.addListener(() {
      int remaining = (_timerController.duration!.inSeconds * (1 - _timerController.value)).round();
      _remainingSeconds.value = remaining;
      if (_timerController.isCompleted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onTimeExpired();
        });
      }
    });
    _timerController.forward(from: 0);
  }

  Future<List<Question>> _loadRandomQuestions() async {
    try {
      final url = Uri.parse('$kBaseUrl$kApiEndpoint');
      print('📡 Attempting to fetch KCET data from: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        print('✅ Server data loaded successfully');
        final List<dynamic> jsonData = jsonDecode(response.body);
        if (jsonData.isEmpty) throw Exception('Empty dataset from server');

        // Shuffle and pick 30 random questions
        List<Question> allQuestions = jsonData.map((q) => Question(
          question: q['question'] ?? 'No question text found',
          options: List<String>.from(q['options'] ?? []),
          answer: q['answer'] ?? '',
        )).toList();

        allQuestions.shuffle(Random());
        final selected = allQuestions.take(30).toList();

        _selectedAnswers = List.filled(selected.length, -1);
        return selected;
      } else {
        print('⚠️ Server error ${response.statusCode}, loading local dataset');
        return await _loadLocalDataset();
      }
    } catch (e) {
      print('❌ Error fetching KCET questions: $e');
      print('📁 Falling back to local dataset...');
      return await _loadLocalDataset();
    }
  }

  Future<List<Question>> _loadLocalDataset() async {
    try {
      final data = await rootBundle.loadString('assets/kcet_questions.json');
      final List<dynamic> jsonData = jsonDecode(data);
      print('📦 Loaded ${jsonData.length} questions from local asset');

      // Shuffle and pick 30 random questions
      List<Question> allQuestions = jsonData.map((q) => Question(
        question: q['question'] ?? 'No question',
        options: List<String>.from(q['options'] ?? []),
        answer: q['answer'] ?? '',
      )).toList();

      allQuestions.shuffle(Random());
      final selected = allQuestions.take(30).toList();

      _selectedAnswers = List.filled(selected.length, -1);
      return selected;
    } catch (e) {
      print('❌ Error loading local dataset: $e');
      rethrow;
    }
  }

  void _selectAnswer(int idx) {
    setState(() {
      _selectedAnswers[_currentIndex] = idx;
    });
  }

  void _next() {
    if (_selectedAnswers[_currentIndex] == -1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an answer first')));
      return;
    }
    if (_currentIndex < _selectedAnswers.length - 1 && !_reviewMode) {
      setState(() { _currentIndex++; });
    } else {
      setState(() { _reviewMode = true; });
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() { _currentIndex--; });
    }
  }

  void _gotoQuestion(int idx) {
    setState(() {
      _currentIndex = idx;
      _reviewMode = false;
    });
  }

  Future<void> _finalSubmit(List<Question> questions) async {
    if (_selectedAnswers.any((ans) => ans == -1)) {
      final cont = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unanswered Questions'),
          content: const Text('Some questions are unanswered. Do you want to submit anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
          ],
        ),
      );
      if (cont != true) return;
    }
    _timerController.stop();
    setState(() { _reviewMode = false; });
    await _showCareerRoadmapPopup(questions, _selectedAnswers);
  }

  void _onTimeExpired() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Time\'s Up!'),
          content: const Text('Your 30 minutes have elapsed. Please submit your answers.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (mounted) _finalSubmitDialog();
              },
              child: const Text('Submit Now'),
            ),
          ],
        )
    );
  }

  Future<void> _finalSubmitDialog() async {
    final qs = await _questionsFuture;
    await _finalSubmit(qs);
  }

  Future<void> _showCareerRoadmapPopup(List<Question> questions, List<int> answers) async {
    setState(() { _loadingAI = true; });

    int correctCount = 0;
    for (int i = 0; i < questions.length; i++) {
      if (_selectedAnswers[i] != -1 && questions[i].options[_selectedAnswers[i]] == questions[i].answer) {
        correctCount++;
      }
    }
    double scorePercent = (correctCount * 100) / questions.length;

    List<String> summarizedAnswers = [];
    for (int i = 0; i < questions.length; i++) {
      String ansText = (_selectedAnswers[i] == -1) ? 'No Answer' : questions[i].options[_selectedAnswers[i]];
      summarizedAnswers.add("Q${i+1}: ${questions[i].question}\nAnswer: $ansText");
    }
    String answersSummary = summarizedAnswers.take(15).join('\n\n');

    String prompt = '''
You are an expert AI course counselor.
Below are a student's answers to KCET-level questions (Physics, Chemistry, Math, and Biology):

$answersSummary

Based on the responses, identify:
1. The student's strengths in STEM subjects wise.
2. Their most suitable course like CS,IS,DS,EC,EEE,ME,Civil which ever suitable for their based on the subject scores.
3. A detailed course roadmap with learning paths, certifications, and projects.
Do NOT use *, •, -, _, or any Markdown symbols. Write as clean, plain text for students. Highlight important areas for improvement. Suggest relevant study links (as a list at end) and provide motivational remarks.
Start report with: 'Your KCET Score: ${scorePercent.toStringAsFixed(1)} out of 100.'
''';

    String aiResponse = '';
    String? error;
    try {
      final apiKey = 'YOUR_API_KEY_HERE';
      final url = Uri.parse('https://api.perplexity.ai/chat/completions');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };
      final body = jsonEncode({
        'model': 'sonar-pro',
        'messages': [{'role':'user', 'content': prompt}],
        'max_tokens': 1400,
        'temperature': 0.7,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        aiResponse = data['choices'][0]['message']['content'] ?? '';
        aiResponse = aiResponse.replaceAll(RegExp(r'[*•\-_#>`]'), ' ').replaceAll('\uFFFD',' ');
      } else {
        error = 'Failed AI response (HTTP ${response.statusCode}): ${response.body}';
      }
    } catch (e) {
      error = 'Error during AI request: $e';
    }
    setState(() { _loadingAI = false; });

    if (!mounted) return;

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Your Course Roadmap', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo[900]))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () {
                    Navigator.pop(context);
                    _resetQuiz();
                  }),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: error != null
                      ? Text(error, style: const TextStyle(color: Colors.red))
                      : Text(aiResponse, style: const TextStyle(fontSize: 16)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake Quiz'),
                    onPressed: () {
                      Navigator.pop(context);
                      _resetQuiz();
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Save PDF'),
                    onPressed: () async {
                      if(aiResponse.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('AI result is empty. Cannot save.'))
                        );
                        return;
                      }
                      await _savePDF(aiResponse, scorePercent);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PDF: remove strange symbols, use spacing logic, highlight sections and roles
  Future<void> _savePDF(String text, double scorePercent) async {
    final doc = pw.Document();

    // Remove unwanted characters and fix spacing issues
    String cleanText = text
        .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E]'), ' ') // Replace unprintable/unicode with space
        .replaceAll('\uFFFD', ' ') // Replace replacement character
        .replaceAll('  ', ' ');

    List<String> lines = cleanText.split('\n');
    final sectionKeywords = [
      "Strengths in STEM", "Physics", "Chemistry", "Mathematics", "Biology",
      "Most suitable roles", "Roadmap", "Improvement", "Score:", "Year"
    ];

    List<pw.Widget> contentWidgets = [
      pw.Text('AI Course Roadmap', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Text('Score: ${scorePercent.toStringAsFixed(1)} out of 100', style: pw.TextStyle(fontSize: 15)),
      pw.Divider()
    ];

    for (String l in lines) {
      String trimmed = l.trim();
      if (trimmed.isEmpty) {
        contentWidgets.add(pw.SizedBox(height: 7));
        continue;
      }
      bool section = sectionKeywords.any((k) => trimmed.startsWith(k));
      if(trimmed.toLowerCase().contains("roles") || trimmed.toLowerCase().contains("designation")) {
        // Highlight roles
        contentWidgets.add(pw.SizedBox(height: 11));
        contentWidgets.add(pw.Text(trimmed, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)));
        contentWidgets.add(pw.SizedBox(height: 4));
      } else if (section || trimmed.startsWith('Year') || trimmed.toLowerCase().contains('roadmap')) {
        // Bold for section headers and roadmap
        contentWidgets.add(pw.SizedBox(height: 11));
        contentWidgets.add(pw.Text(trimmed, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)));
        contentWidgets.add(pw.SizedBox(height: 3));
      } else if (trimmed.startsWith("Junior") || trimmed.startsWith("STEM") || trimmed.startsWith("Science/Math") || trimmed.startsWith("Data Entry") || trimmed.startsWith('Apply for internships')) {
        // Bullet roles and action lines
        contentWidgets.add(pw.Bullet(text: trimmed, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)));
      } else {
        // Normal paragraph
        contentWidgets.add(pw.Text(trimmed, style: pw.TextStyle(fontSize: 12)));
      }
    }

    doc.addPage(pw.MultiPage(
        maxPages: 2,
        build: (context) => contentWidgets
    ));

    final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final file = File('${dir.path}/course_roadmap_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await doc.save());
    await OpenFile.open(file.path);
  }

  void _resetQuiz() {
    _timerController.stop();
    _initQuiz();
    setState(() {
      _currentIndex = 0;
      _reviewMode = false;
      _selectedAnswers = List.filled(30, -1);
      _quizStarted = false;
    });
  }

  @override
  void dispose() {
    _timerController.dispose();
    _remainingSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: const [_LogoutButton()],
      ),
      body: Stack(
        children: [
          _quizStarted ? _buildQuizUI() : _buildWelcomeScreen(),
          if(_loadingAI)
            Container(
              color: Colors.white.withOpacity(0.88),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, color: Colors.indigo[700], size: 80),
          const SizedBox(height: 26),
          Text('Welcome to the Course Roadmap Analyzer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.indigo[900]), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'This quiz consists of 30 multiple-choice questions across:\n'
                  'Physics, Chemistry, Mathematics, Biology\n\n'
                  'You have 30 minutes to complete the quiz. Read each question carefully and select the best answer. Good luck, and get ready to discover your strengths!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.indigo,
            ),
            icon: const Icon(Icons.play_arrow, size: 28, color: Colors.white),
            label: const Text('Start Quiz', style: TextStyle(fontSize: 20, color: Colors.white)),
            onPressed: _startQuiz,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizUI() {
    return FutureBuilder<List<Question>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        if(snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if(snapshot.hasError)
          return Center(child: Text('Error loading questions: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        if(!snapshot.hasData) return const Center(child: Text('No questions available.'));

        final questions = snapshot.data!;
        if(_reviewMode) return _buildReviewScreen(questions);

        return _buildQuizScreen(questions);
      },
    );
  }

  Widget _buildQuizScreen(List<Question> questions) {
    final q = questions[_currentIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentIndex + 1) / questions.length,
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<int>(
              valueListenable: _remainingSeconds,
              builder: (context, seconds, _) {
                final minutes = seconds ~/ 60;
                final remSecs = seconds % 60;
                return Text('Time Left: ${minutes.toString().padLeft(2,'0')}:${remSecs.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 16));
              }
          ),
          const SizedBox(height: 12),
          Text('Question ${_currentIndex + 1} of ${questions.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Text(q.question, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 22),
          ...q.options.asMap().entries.map((entry) {
            int idx = entry.key;
            String option = entry.value;
            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: Radio<int>(
                  value: idx,
                  groupValue: _selectedAnswers[_currentIndex],
                  onChanged: (val) => _selectAnswer(val!),
                ),
                title: Text(option, style: const TextStyle(fontSize: 16)),
                onTap: () => _selectAnswer(idx),
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
          Row(
            children: [
              if(_currentIndex > 0)
                Expanded(child: ElevatedButton(onPressed: _previous, child: const Text('Previous'))),
              if(_currentIndex > 0) const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loadingAI ? null : _next,
                  child: Text(_currentIndex == questions.length - 1 ? 'Review & Submit' : 'Next'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildReviewScreen(List<Question> questions) {
    int answeredCount = _selectedAnswers.where((a) => a != -1).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Review & Submit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Questions answered: $answeredCount / ${questions.length}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 14),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: questions.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, idx) {
              final q = questions[idx];
              final ansIdx = _selectedAnswers[idx];
              return ListTile(
                title: Text('Q${idx+1}: ${q.question}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(ansIdx == -1 ? 'Not Answered' : q.options[ansIdx], style: TextStyle(color: ansIdx == -1 ? Colors.red : Colors.green)),
                trailing: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _reviewMode = false;
                      _currentIndex = idx;
                    });
                  },
                  child: const Text('Edit'),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text("Final Submit & Get Course Roadmap"),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: () async {
              final questions = await _questionsFuture;
              await _finalSubmit(questions);
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text("Restart Quiz"),
            onPressed: () { _resetQuiz(); },
          )
        ],
      ),
    );
  }
}

class Question {
  final String question;
  final List<String> options;
  final String answer;

  Question({required this.question, required this.options, required this.answer});
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

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
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ),
      ],
    );
  }
}