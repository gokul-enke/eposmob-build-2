class FaqModel {
  final String status;
  final String message;
  final List<FaqData> data;

  FaqModel({required this.status, required this.message, required this.data});

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List;
    List<FaqData> faqDataList = list.map((i) => FaqData.fromJson(i)).toList();

    return FaqModel(
      status: json['status'] as String,
      message: json['message'] as String,
      data: faqDataList,
    );
  }
}

class FaqData {
  final int id;
  final int companyId;
  final String? question;
  final String questionSlug;
  final String answer;
  final DateTime createdAt;
  final DateTime updatedAt;

  FaqData({
    required this.id,
    required this.companyId,
    this.question,
    required this.questionSlug,
    required this.answer,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FaqData.fromJson(Map<String, dynamic> json) {
    return FaqData(
      id: json['id'] as int,
      companyId: json['company_id'] as int,
      question: json['question'] as String?,
      questionSlug: json['question_slug'] as String,
      answer: json['answer'] as String,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
