enum TransactionType { income, expense }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
    this.slipImagePath,
  });

  final int? id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String note;
  final String? slipImagePath;

  bool get isIncome => type == TransactionType.income;

  WalletTransaction copyWith({
    int? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? note,
    String? slipImagePath,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      slipImagePath: slipImagePath ?? this.slipImagePath,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'type': type.name,
    'category': category,
    'date': date.toIso8601String(),
    'note': note,
    'slip_image_path': slipImagePath,
  };

  factory WalletTransaction.fromMap(Map<String, Object?> map) {
    return WalletTransaction(
      id: map['id'] as int,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.byName(map['type'] as String),
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String? ?? '',
      slipImagePath: map['slip_image_path'] as String?,
    );
  }
}

const transactionCategories = <String>[
  'อาหาร',
  'เดินทาง',
  'ช้อปปิ้ง',
  'บิล/ค่าน้ำไฟ',
  'สุขภาพ',
  'การศึกษา',
  'เงินเดือน',
  'เงินพิเศษ',
  'อื่น ๆ',
];
