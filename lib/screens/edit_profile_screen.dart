import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../services/drug_api_service.dart';
import '../services/system_api_service.dart';
import 'home_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isFirstRun;
  const EditProfileScreen({super.key, this.isFirstRun = false});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _selectedDrug;
  int _currentInterval = 120;

  List<String> _bloodGroups = [];
  List<String> _rhFactors = [];
  String _selectedBloodGroup = "-";
  String _selectedRh = "Unknown";
  bool _isLoadingApi = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playTapSound() async {
    await _audioPlayer.play(AssetSource('sounds/water.mp3'));
  }

  Future<void> _initData() async {
    final apiData = await SystemApiService.fetchBloodData();
    setState(() {
      _bloodGroups = apiData['groups']!;
      _rhFactors = apiData['rh']!;
      _isLoadingApi = false;
    });

    if (!widget.isFirstRun) {
      await _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final db = DatabaseHelper();
    final user = await db.getUser();
    if (user != null) {
      setState(() {
        _nameController.text = user.name;
        _selectedDrug = user.allergies;
        _conditionController.text = user.medicalConditions;
        _emergencyPhoneController.text = user.emergencyPhone;
        _addressController.text = user.address;
        _historyController.text = user.medicalHistory;
        _emailController.text = user.emergencyEmail ?? "";
        _currentInterval = user.checkInInterval;
        _parseBloodType(user.bloodType);
      });
    }
  }

  void _parseBloodType(String fullBloodType) {
    if (fullBloodType == "-" || fullBloodType.isEmpty) {
      _selectedBloodGroup = "-";
      _selectedRh = "Unknown";
      return;
    }
    String lastChar = fullBloodType.substring(fullBloodType.length - 1);
    if (lastChar == "+" || lastChar == "-") {
      _selectedRh = lastChar;
      _selectedBloodGroup = fullBloodType.substring(0, fullBloodType.length - 1);
    } else {
      _selectedBloodGroup = fullBloodType;
      _selectedRh = "Unknown";
    }
    if (!_bloodGroups.contains(_selectedBloodGroup)) _selectedBloodGroup = "-";
    if (!_rhFactors.contains(_selectedRh)) _selectedRh = "Unknown";
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      String finalBloodType = "";
      if (_selectedBloodGroup == "-") {
        finalBloodType = "-";
      } else {
        finalBloodType = _selectedBloodGroup + (_selectedRh == "Unknown" ? "" : _selectedRh);
      }

      // โหลดข้อมูลผู้ใช้เดิมเพื่อคงค่าสถานะโหมด
      final db = DatabaseHelper();
      final existingUser = await db.getUser();

      final user = UserProfile(
        id: 1,
        name: _nameController.text,
        bloodType: finalBloodType,
        allergies: _selectedDrug ?? "ไม่แพ้ยา",
        medicalConditions: _conditionController.text,
        emergencyPhone: _emergencyPhoneController.text,
        emergencyEmail: _emailController.text,
        lastCheckIn: existingUser?.lastCheckIn,
        address: _addressController.text,
        medicalHistory: _historyController.text,
        checkInInterval: _currentInterval,
        isTrackingMode: existingUser?.isTrackingMode ?? false,
        isEmergencyMode: existingUser?.isEmergencyMode ?? false,
        isDarkMode: existingUser?.isDarkMode ?? false,
      );

      await db.saveUser(user);

      if (widget.isFirstRun) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_complete', true);
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อย')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoadingApi
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- Header ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                            onPressed: () {
                              _playTapSound();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Personal Info",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Scrollable Content ---
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        child: Column(
                          children: [
                            // === Section 1: Basic Information ===
                            _buildSectionCard(
                              icon: Icons.person_outline,
                              title: "Basic Information",
                              children: [
                                _buildTextField(
                                  controller: _nameController,
                                  hint: "Full Name",
                                  validator: (v) => v!.isEmpty ? "กรุณากรอกชื่อ" : null,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _addressController,
                                  hint: "Current Address",
                                  maxLines: 2,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // === Section 2: Blood Type ===
                            _buildSectionCard(
                              icon: Icons.water_drop,
                              iconColor: Colors.red,
                              title: "Blood Type",
                              children: [
                                Row(
                                  children: [
                                    // Blood Group
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Blood Group", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            children: _bloodGroups.where((bg) => bg != "-").map((bg) {
                                              return ChoiceChip(
                                                label: Text(bg),
                                                selected: _selectedBloodGroup == bg,
                                                onSelected: (selected) {
                                                  _playTapSound();
                                                  setState(() => _selectedBloodGroup = selected ? bg : "-");
                                                },
                                                selectedColor: Colors.grey.shade300,
                                                backgroundColor: Colors.grey.shade100,
                                                labelStyle: TextStyle(
                                                  color: _selectedBloodGroup == bg ? Colors.black : Colors.grey.shade600,
                                                  fontWeight: _selectedBloodGroup == bg ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Rh Factor
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Rh Factor", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            children: _rhFactors.where((rh) => rh != "Unknown").map((rh) {
                                              return ChoiceChip(
                                                label: Text(rh),
                                                selected: _selectedRh == rh,
                                                onSelected: (selected) {
                                                  _playTapSound();
                                                  setState(() => _selectedRh = selected ? rh : "Unknown");
                                                },
                                                selectedColor: Colors.grey.shade300,
                                                backgroundColor: Colors.grey.shade100,
                                                labelStyle: TextStyle(
                                                  color: _selectedRh == rh ? Colors.black : Colors.grey.shade600,
                                                  fontWeight: _selectedRh == rh ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // === Section 3: Medical Details ===
                            _buildSectionCard(
                              icon: Icons.verified_user_outlined,
                              title: "Medical Details",
                              children: [
                                DrugAutocompleteField(
                                  initialValue: _selectedDrug,
                                  onSelected: (selection) {
                                    _playTapSound();
                                    setState(() => _selectedDrug = selection);
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _conditionController,
                                  hint: "Medical Conditions",
                                  prefixIcon: Icons.medical_services_outlined,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _historyController,
                                  hint: "Medical History",
                                  prefixIcon: Icons.history,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // === Section 4: Emergency Contacts ===
                            _buildSectionCard(
                              icon: Icons.phone_outlined,
                              title: "Emergency Contacts",
                              children: [
                                _buildTextField(
                                  controller: _emergencyPhoneController,
                                  hint: "Primary Emergency Contact",
                                  prefixIcon: Icons.call,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => v!.isEmpty ? "กรุณากรอกเบอร์" : null,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _emailController,
                                  hint: "Emergency Email",
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Save Button ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            _playTapSound();
                            _saveProfile();
                          },
                          child: const Text(
                            "Save Information",
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // === Helper: Section Card ===
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color iconColor = Colors.black87,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // === Helper: TextField ===
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade400) : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
      ),
    );
  }
}

// === Drug Autocomplete Field ===
class DrugAutocompleteField extends StatelessWidget {
  final Function(String) onSelected;
  final String? initialValue;

  const DrugAutocompleteField({super.key, required this.onSelected, this.initialValue});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: initialValue != null ? TextEditingValue(text: initialValue!) : null,
      optionsBuilder: (TextEditingValue textEditingValue) async {
        return await DrugApiService.searchDrugs(textEditingValue.text);
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          decoration: InputDecoration(
            hintText: 'Allergies & Conditions (Search)',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            suffixIcon: Icon(Icons.search, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
          ),
        );
      },
    );
  }
}
