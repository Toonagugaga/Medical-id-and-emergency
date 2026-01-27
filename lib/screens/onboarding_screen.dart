import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'edit_profile_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentPage = 0;

  List<Map<String, String>> onboardingData = [
    {
      "title": "ยินดีต้อนรับสู่ Medical ID",
      "text": "แอปพลิเคชันช่วยชีวิตที่จะเก็บข้อมูลทางการแพทย์ของคุณไว้ในยามฉุกเฉิน",
      "image": "assets/animations/Medical-Shield.json",
    },
    {
      "title": "ความยินยอมข้อมูลส่วนบุคคล",
      "text": "เราจะเก็บข้อมูลของคุณไว้บนเครื่องนี้เท่านั้น เพื่อใช้แสดงผลกรณีฉุกเฉิน คุณยอมรับเงื่อนไขหรือไม่?",
      "image": "assets/animations/Medical-report.json",
    },
    {"title": "พร้อมเริ่มต้นใช้งาน", "text": "กรอกข้อมูลสุขภาพของคุณ เพื่อความปลอดภัยสูงสุด", "image": "assets/animations/heart.json"},
  ];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound() async {
    await _audioPlayer.play(AssetSource('sounds/water.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: onboardingData.length,
                itemBuilder: (context, index) => OnboardingContent(
                  title: onboardingData[index]["title"]!,
                  text: onboardingData[index]["text"]!,
                  image: onboardingData[index]["image"]!,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(onboardingData.length, (index) => buildDot(index: index)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _playSound(); // เล่นเสียงเมื่อกด
                    if (_currentPage == onboardingData.length - 1) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EditProfileScreen(isFirstRun: true)));
                    } else {
                      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                    }
                  },
                  child: Text(
                    _currentPage == onboardingData.length - 1
                        ? "มาเริ่มกันเลย"
                        : _currentPage == 1
                        ? "ตกลง"
                        : "ถัดไป",
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AnimatedContainer buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 5),
      height: 6,
      width: _currentPage == index ? 20 : 6,
      decoration: BoxDecoration(color: _currentPage == index ? Colors.blue : Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
    );
  }
}

class OnboardingContent extends StatelessWidget {
  final String title, text, image;

  const OnboardingContent({super.key, required this.title, required this.text, required this.image});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(image, height: 300, width: 300, fit: BoxFit.contain),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 15),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
