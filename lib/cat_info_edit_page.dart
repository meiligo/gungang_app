import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CatInfoEditPage extends StatefulWidget {
  @override
  _CatInfoEditPageState createState() => _CatInfoEditPageState();
}

class _CatInfoEditPageState extends State<CatInfoEditPage> {
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
  String? _originalImagePath;

  final List<String> _breeds = ['코리안숏헤어', '믹스', '러시안블루', '페르시안', '기타'];
  final List<String> _neuteredOptions = ['예', '아니오', '모름'];
  final List<String> _gender = ['남', '녀'];

  @override
  void initState() {
    super.initState();
    _loadCatInfo();
  }

  Future<void> _loadCatInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nameController.text = prefs.getString('catName') ?? '';
      final birthDateString = prefs.getString('catBirthDate');
      _selectedBirthDate = birthDateString != null ? DateTime.parse(birthDateString) : null;
      _selectedWeight = prefs.getDouble('catWeight');
      _selectedBreed = prefs.getString('catBreed');

      final loadedGender = prefs.getString('catGender');
      _selectedgender = _gender.contains(loadedGender) ? loadedGender : null;

      _selectedTargetWeight = prefs.getDouble('catTargetWeight');
      final adoptDateString = prefs.getString('catAdoptDate');
      _selectedAdoptDate = adoptDateString != null ? DateTime.parse(adoptDateString) : null;
      _selectedNeuteredStatus = prefs.getString('catNeuteredStatus');
      _originalImagePath = prefs.getString('catImagePath');
      if (_originalImagePath != null) {
        _selectedImageFile = File(_originalImagePath!);
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImageFile = File(image.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context, Function(DateTime) onDateSelected) async {
    final picked = await showDatePicker(
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
  Future<void> _selectNumber(BuildContext context, String title, double initialValue, Function(double) onNumberSelected,
      {int maxInteger = 30, int maxFraction = 9}) async {
    double selectedValue = initialValue;
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height / 3,
          child: Column(
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: (initialValue * 10).toInt()),
                  itemExtent: 32,
                  onSelectedItemChanged: (index) {
                    selectedValue = index / 10.0;
                  },
                  children: List.generate(maxInteger * 10 + maxFraction + 1,
                          (index) => Center(child: Text('${(index / 10.0).toStringAsFixed(1)} kg'))),
                ),
              ),
              TextButton(
                child: Text('선택 완료'),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => onNumberSelected(selectedValue));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveCatInfo() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('catName', nameController.text);
      if (_selectedBirthDate != null)
        await prefs.setString('catBirthDate', DateFormat('yyyy-MM-dd').format(_selectedBirthDate!));
      if (_selectedWeight != null)
        await prefs.setDouble('catWeight', _selectedWeight!);
      await prefs.setString('catBreed', _selectedBreed ?? '');
      await prefs.setString('catGender', _selectedgender ?? '');
      if (_selectedTargetWeight != null)
        await prefs.setDouble('catTargetWeight', _selectedTargetWeight!);
      if (_selectedAdoptDate != null)
        await prefs.setString('catAdoptDate', DateFormat('yyyy-MM-dd').format(_selectedAdoptDate!));
      await prefs.setString('catNeuteredStatus', _selectedNeuteredStatus ?? '');

      if (_selectedImageFile != null) {
        await prefs.setString('cat_Image_Path', _selectedImageFile!.path);
      } else if (_originalImagePath == null) {
        await prefs.remove('cat_Image_Path');
      }

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
        image: DecorationImage(
        image: AssetImage('lib/assets/bg1.png'), // 이미지 경로
    fit: BoxFit.cover, // 화면에 꽉 차게 설정
    ),
    ),
    child:  Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
    backgroundColor: Colors.transparent,
      title: Row(
        mainAxisSize: MainAxisSize.min, // Row의 크기를 내용물에 맞게 최소화
        children: [
          Image.asset(
            'lib/assets/set_icon.png', // 여기에 이미지 경로를 넣어줘
            width: 24, // 아이콘 크기 조절
            height: 24,
          ),
          const SizedBox(width: 8), // 아이콘과 텍스트 사이 간격
          const Text(
            '고양이 정보 수정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('사진 변경'),
              SizedBox(height: 10),
              InkWell(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _selectedImageFile != null
                      ? FileImage(_selectedImageFile!)
                      : (_originalImagePath != null ? FileImage(File(_originalImagePath!)) : null),
                  child: _selectedImageFile == null && _originalImagePath == null
                      ? Icon(Icons.add_a_photo, size: 50, color: Colors.grey[600])
                      : null,
                ),
              ),
              SizedBox(height: 30),
              _buildTextFormField('이름 *',
                  controller: nameController),
              _buildDropdownField('성별',
                  _selectedgender,
                  _gender,
                      (val) => _selectedgender = val),
              _buildDropdownField('중성화 여부 *',
                  _selectedNeuteredStatus,
                  _neuteredOptions, (val) => _selectedNeuteredStatus = val),
              _buildDropdownField('품종',
                  _selectedBreed,
                  _breeds,
                      (val) => _selectedBreed = val),
              _buildNumberSelectionField('현재 몸무게 *',
                  _selectedWeight, () => _selectNumber(context,
                      '현재 몸무게 선택',
                      _selectedWeight ?? 3.0, (w) => _selectedWeight = w)),

              _buildNumberSelectionField('목표 체중',
                  _selectedTargetWeight,
                      () => _selectNumber(context,
                      '목표 체중 선택',
                      _selectedTargetWeight ?? 4.0, (w) => _selectedTargetWeight = w)),
              _buildDateSelectionField('생년월일 *',
                  _selectedBirthDate,
                      () => _selectDate(context, (d) => _selectedBirthDate = d)),
              _buildDateSelectionField('입양일',
                  _selectedAdoptDate,
                      () => _selectDate(context, (d) => _selectedAdoptDate = d)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveCatInfo,
                  child: Text('수정', style: TextStyle(color: Colors.white, fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xffd4a373),
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildTextFormField(String label, {required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        validator: (value) => value == null || value.isEmpty ? '필수 입력 항목입니다.' : null,
      ),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : null,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: (val) => setState(() => onChanged(val)),
        validator: (val) => val == null || val.isEmpty ? '필수 선택 항목입니다.' : null,
      ),
    );
  }

  Widget _buildDateSelectionField(String label, DateTime? selectedDate, VoidCallback onTap) {
    final controller = TextEditingController(
      text: selectedDate == null ? '' : DateFormat('yyyy년 MM월 dd일').format(selectedDate),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
        onTap: onTap,
        validator: (_) => controller.text.isEmpty ? '날짜를 선택해주세요.' : null,
      ),
    );
  }

  Widget _buildNumberSelectionField(String label, double? selectedValue, VoidCallback onTap) {
    final controller = TextEditingController(text: selectedValue == null ? '' : '${selectedValue.toStringAsFixed(1)} kg');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(), suffixIcon: Icon(Icons.arrow_drop_down)),
        onTap: onTap,
        validator: (_) => controller.text.isEmpty ? '숫자를 선택해주세요.' : null,
      ),
    );
  }
}
