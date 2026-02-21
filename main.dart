import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

/// 入力された文字列（ひらがなや半角カタカナ）を全角カタカナに変換する関数
String convertToKatakana(String input) {
  const Map<String, String> halfWidthMap = {
    '\uFF66': 'ヲ',
    '\uFF67': 'ァ',
    '\uFF68': 'ィ',
    '\uFF69': 'ゥ',
    '\uFF6A': 'ェ',
    '\uFF6B': 'ォ',
    '\uFF6C': 'ャ',
    '\uFF6D': 'ュ',
    '\uFF6E': 'ョ',
    '\uFF6F': 'ッ',
    '\uFF70': 'ー',
    '\uFF71': 'ア',
    '\uFF72': 'イ',
    '\uFF73': 'ウ',
    '\uFF74': 'エ',
    '\uFF75': 'オ',
    '\uFF76': 'カ',
    '\uFF77': 'キ',
    '\uFF78': 'ク',
    '\uFF79': 'ケ',
    '\uFF7A': 'コ',
    '\uFF7B': 'サ',
    '\uFF7C': 'シ',
    '\uFF7D': 'ス',
    '\uFF7E': 'セ',
    '\uFF7F': 'ソ',
    '\uFF80': 'タ',
    '\uFF81': 'チ',
    '\uFF82': 'ツ',
    '\uFF83': 'テ',
    '\uFF84': 'ト',
    '\uFF85': 'ナ',
    '\uFF86': 'ニ',
    '\uFF87': 'ヌ',
    '\uFF88': 'ネ',
    '\uFF89': 'ノ',
    '\uFF8A': 'ハ',
    '\uFF8B': 'ヒ',
    '\uFF8C': 'フ',
    '\uFF8D': 'ヘ',
    '\uFF8E': 'ホ',
    '\uFF8F': 'マ',
    '\uFF90': 'ミ',
    '\uFF91': 'ム',
    '\uFF92': 'メ',
    '\uFF93': 'モ',
    '\uFF94': 'ヤ',
    '\uFF95': 'ユ',
    '\uFF96': 'ヨ',
    '\uFF97': 'ラ',
    '\uFF98': 'リ',
    '\uFF99': 'ル',
    '\uFF9A': 'レ',
    '\uFF9B': 'ロ',
    '\uFF9C': 'ワ',
    '\uFF9D': 'ン',
    '\uFF9E': '゛',
    '\uFF9F': '゜',
  };

  final buffer = StringBuffer();
  for (final code in input.runes) {
    final char = String.fromCharCode(code);
    // ひらがな (U+3041～U+3096) → 全角カタカナ (U+30A1～U+30F6)
    final cu = char.codeUnitAt(0);
    if (cu >= 0x3041 && cu <= 0x3096) {
      final newCode = cu + 0x60;
      buffer.write(String.fromCharCode(newCode));
    } else if (halfWidthMap.containsKey(char)) {
      // 半角カタカナならマッピングで全角に変換
      buffer.write(halfWidthMap[char]);
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// TextInputFormatter: IME の編集中（composing中）は変換せず、確定後にのみ全角カタカナ変換
class KatakanaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // composing中ならそのまま返す（変換しない）
    if (newValue.composing.isValid && newValue.composing != TextRange.empty) {
      return newValue;
    }
    final converted = convertToKatakana(newValue.text);
    return TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
      composing: TextRange.empty,
    );
  }
}

class Medicine {
  final String category;
  final String genericName;
  final String productName;
  final String period;
  final String note;
  final String shortCode;

  const Medicine({
    required this.category,
    required this.genericName,
    required this.productName,
    required this.period,
    required this.note,
    required this.shortCode,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      category: json['category'] as String,
      genericName: json['genericName'] as String,
      productName: json['productName'] as String,
      period: json['period'] as String,
      note: json['note'] as String,
      shortCode: json['shortCode'].toString(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '周術期休止薬',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MedicineSearchPage(),
    );
  }
}

class MedicineSearchPage extends StatefulWidget {
  const MedicineSearchPage({super.key});

  @override
  State<MedicineSearchPage> createState() => _MedicineSearchPageState();
}

class _MedicineSearchPageState extends State<MedicineSearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Medicine> _medicines = [];
  Medicine? _foundMedicine;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/medicines.json');
      final List<dynamic> jsonResponse =
          json.decode(jsonString) as List<dynamic>;
      setState(() {
        _medicines = jsonResponse
            .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      setState(() {
        _message = 'JSONの読み込みエラー: $e';
      });
    }
  }

  void _clearResult() {
    setState(() {
      _foundMedicine = null;
      _message = '';
    });
  }

  void _searchMedicine() {
    final raw = _controller.text.trim();
    if (raw.length < 3) {
      setState(() {
        _foundMedicine = null;
        _message = '3文字以上で入力してください';
      });
      return;
    }

    // 入力も同じルールで正規化（ひらがな/半角カナ→全角カナ）
    final query = convertToKatakana(raw);

    Medicine? result;

    // ① まず商品名(productName)で検索（先頭一致）
    for (final med in _medicines) {
      final p = convertToKatakana(med.productName);
      if (p.startsWith(query)) {
        result = med;
        break;
      }
    }

    // ② 商品名で見つからなければ一般名(genericName)で検索（先頭一致）
    if (result == null) {
      for (final med in _medicines) {
        final g = convertToKatakana(med.genericName);
        if (g.startsWith(query)) {
          result = med;
          break;
        }
      }
    }

    setState(() {
      if (result != null) {
        _foundMedicine = result;
        _message = '';
      } else {
        _foundMedicine = null;
        _message = '手術時の休止薬に該当しません';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('周術期休止薬')),
      // 入力欄を最上部に、結果はその下でスクロール
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // === 入力エリア（最上部・固定） ===
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      inputFormatters: [KatakanaInputFormatter()],
                      decoration: const InputDecoration(
                        hintText: 'できるだけ3文字以上で入力',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _searchMedicine(),
                      onChanged: (_) => _clearResult(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _searchMedicine,
                    child: const Text('検索'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // === 結果表示エリア（下側・スクロール可能） ===
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_foundMedicine != null) ...[
                        _ResultRow(
                            label: '商品名', value: _foundMedicine!.productName),
                        const SizedBox(height: 6),
                        _ResultRow(
                            label: '一般名', value: _foundMedicine!.genericName),
                        const SizedBox(height: 6),
                        _ResultRow(
                            label: '分類', value: _foundMedicine!.category),
                        const SizedBox(height: 6),
                        _ResultRow(
                            label: '休薬期間', value: _foundMedicine!.period),
                        if (_foundMedicine!.note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _ResultRow(label: '備考', value: _foundMedicine!.note),
                        ],
                      ] else if (_message.isNotEmpty) ...[
                        Text(_message,
                            style: const TextStyle(color: Colors.red)),
                      ] else ...[
                        const Text(
                          '上の入力欄に薬剤名（カタカナ 3文字以上推奨）を入力して検索してください。',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 見出し＋値を横並びで表示する行ウィジェット
class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
