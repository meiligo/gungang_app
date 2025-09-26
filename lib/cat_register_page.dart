import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CatRegisterPage extends StatefulWidget {
  @override
  _CatRegisterPageState createState() => _CatRegisterPageState();
}

class _CatRegisterPageState extends State<CatRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  DateTime? _selectedBirthDate;
  double? _selectedWeight;
  String? _selectedBreed;
  String? _selectedgender;
  double? _selectedTargetWeight;
  DateTime? _selectedAdoptDate;
  String? _selectedNeuteredStatus;
  File? _selectedImageFile;


  final List<String> _breeds = ['코리안숏헤어', '믹스', '러시안블루', '페르시안', '기타'];
  final List<String> _neuteredOptions = ['예', '아니오', '모름'];
  final List<String> _gender = ['남', '녀'];
  @override
  void initState() {
    super.initState();
    _checkIfCatExists();
  }

  // ✅ 선택한 이미지를 앱 전용 폴더에 복사하고, 경로를 SharedPreferences에 저장
  Future<String?> _saveCatImageLocally(File pickedFile) async {
    try {
      final dir = await getApplicationDocumentsDirectory(); // 앱 전용 폴더
      final ext = pickedFile.path.split('.').last.toLowerCase();
      final savePath = '${dir.path}/cat_profile.$ext'; // 고정 파일명 추천

      // 복사(덮어쓰기)
      await pickedFile.copy(savePath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cat_image_path', savePath); // ✅ 홈에서 이 키로 읽음

      debugPrint('✅ 로컬 이미지 저장: $savePath');
      return savePath;
    } catch (e) {
      debugPrint('❌ 로컬 이미지 저장 실패: $e');
      return null;
    }
  }



  Future<void> _checkIfCatExists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('userId');

    if (userId == null) return;

    final response = await http.get(
      Uri.parse('http://192.168.100.130:3000/api/cats/$userId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("서버 응답 데이터: $data");

      if (data is List && data.isNotEmpty) {
        final cat = data[0]; // 리스트의 첫 고양이 정보
        if (cat['name'] != null) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }

    }
  }



  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImageFile = File(image.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context, Function(DateTime) onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        onDateSelected(picked);
      });
    }
  }

  Future<void> _selectNumber(BuildContext context, String title, double initialValue,
      Function(double) onNumberSelected, {int maxInteger = 30, int maxFraction = 9}) async {
    double selectedValue = initialValue;
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext builder) {
        return Container(
          height: MediaQuery.of(context).copyWith().size.height / 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: (initialValue * 10).toInt()),
                  itemExtent: 32.0,
                  onSelectedItemChanged: (int index) {
                    selectedValue = index / 10.0;
                  },
                  children: List<Widget>.generate(maxInteger * 10 + maxFraction + 1,
                          (int index) => Center(child: Text('${(index / 10.0).toStringAsFixed(1)} kg'))),
                ),
              ),
              TextButton(
                child: Text('선택 완료'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    onNumberSelected(selectedValue);
                  });
                },
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveCatInfo() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId'); // 로그인 시 저장된 값

      //userId DB값 확인하기 07_07
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 정보가 없습니다. 다시 로그인해주세요.')),
        );
        return;
      }

      if (_selectedImageFile != null) {
        await _saveCatImageLocally(_selectedImageFile!);
      }

      // 중성화 여부 변환
      bool? neuteredBool;
      if (_selectedNeuteredStatus == '예') neuteredBool = true;
      else if (_selectedNeuteredStatus == '아니오') neuteredBool = false;

      // 성별 변환
      String? genderEnum;
      if (_selectedgender == '남') genderEnum = 'male';
      else if (_selectedgender == '녀') genderEnum = 'female';

      final url = Uri.parse('http://192.168.100.130:3000/api/cats');

      final Map<String, dynamic> catData = {
        'user_id': userId,
        'name': nameController.text,
        'birth_date': _selectedBirthDate?.toIso8601String(),
        'current_weight': _selectedWeight,
        'breed': _selectedBreed,
        'gender': genderEnum,
        //'target_weight_status': _selectedTargetWeight != null ? '설정됨' : '미설정',
        'target_weight': _selectedTargetWeight,
        'adoption_date': _selectedAdoptDate?.toIso8601String(),
        'neutered': neuteredBool,
        'weight_updated_at': DateTime.now().toIso8601String(), // 지금 시간
        'profile_image': '', // 아직 파일 업로드 구현 안 했으므로 빈 문자열 처리
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(catData),
      );

      if (response.statusCode == 201) {
        await prefs.setBool('isCatRegistered', true);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        print(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: ${response.body}')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
        // 전체를 Container로 감싸고 배경 이미지 설정
          decoration: const BoxDecoration(
          image: DecorationImage(
          image: AssetImage('lib/assets/bg1.png'), // 이미지 경로
      fit: BoxFit.cover, // 화면에 꽉 차게 설정
      ),
    ),

      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('고양이 정보 입력', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('사진 등록', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Center(
                child: InkWell(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                    _selectedImageFile != null ? FileImage(_selectedImageFile!) : null,
                    child: _selectedImageFile == null
                        ? Icon(Icons.add_a_photo, size: 50, color: Colors.grey[600])
                        : null,
                  ),
                ),
              ),
              SizedBox(height: 30),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '이름 *',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.black),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff5f33e1), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                cursorColor: Colors.black,
                validator: (value) => value!.isEmpty ? '이름을 입력해주세요' : null,
              ),
              SizedBox(height: 16),
              _buildDropdownField(
                label: '성별',
                value: _selectedgender,
                items: _gender,
                onChanged: (value) => setState(() => _selectedgender = value),
              ),
              _buildDropdownField(
                label: '중성화 여부 *',
                value: _selectedNeuteredStatus,
                items: _neuteredOptions,
                onChanged: (value) => setState(() => _selectedNeuteredStatus = value),
                validator: (value) => value == null ? '중성화 여부를 선택해주세요' : null,
              ),
              _buildDropdownField(
                label: '품종',
                value: _selectedBreed,
                items: _breeds,
                onChanged: (value) => setState(() => _selectedBreed = value),
              ),
              _buildNumberSelectionField(
                label: '현재 몸무게 *',
                selectedValue: _selectedWeight,
                onTap: () => _selectNumber(context, '현재 몸무게 선택', _selectedWeight ?? 3.0,
                        (weight) => _selectedWeight = weight),
                validator: (value) => value == null ? '몸무게를 입력해주세요' : null,
              ),
              _buildNumberSelectionField(
                label: '목표 체중',
                selectedValue: _selectedTargetWeight,
                onTap: () => _selectNumber(context, '목표 체중 선택', _selectedTargetWeight ?? 3.0,
                        (weight) => _selectedTargetWeight = weight),
              ),
              _buildDateSelectionField(
                label: '생년월일 *',
                selectedDate: _selectedBirthDate,
                onTap: () => _selectDate(context, (date) => _selectedBirthDate = date),
                validator: (value) => value == null ? '생년월일을 선택해주세요' : null,
              ),
              _buildDateSelectionField(
                label: '입양일',
                selectedDate: _selectedAdoptDate,
                onTap: () => _selectDate(context, (date) => _selectedAdoptDate = date),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveCatInfo,
                child: Text('등록', style: TextStyle(color: Colors.white, fontSize: 25)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  backgroundColor: Color(0xff5f33e1),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildDateSelectionField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
    FormFieldValidator<String>? validator,
  }) {
    final TextEditingController controller = TextEditingController(
        text: selectedDate == null ? '' : DateFormat('yyyy년 MM월 dd일').format(selectedDate));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.text = selectedDate == null ? '' : DateFormat('yyyy년 MM월 dd일').format(selectedDate);
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        onTap: onTap,
        validator: validator == null ? null : (_) => validator(controller.text.isEmpty ? null : controller.text),
      ),
    );
  }

  Widget _buildNumberSelectionField({
    required String label,
    required double? selectedValue,
    required VoidCallback onTap,
    FormFieldValidator<String>? validator,
  }) {
    final TextEditingController controller = TextEditingController(
        text: selectedValue == null ? '' : '${selectedValue.toStringAsFixed(1)} kg');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.text = selectedValue == null ? '' : '${selectedValue.toStringAsFixed(1)} kg';
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        onTap: onTap,
        validator: validator == null ? null : (_) => validator(controller.text.isEmpty ? null : controller.text),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}
