class Todo {

  Todo({
    required this.id,
    required this.title,
    required this.isComplete,
    this.userId,
  });

  Todo.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        title = json['title'] as String,
        isComplete = json['is_complete'] as bool,
        userId = json['user_id'] as String?;
  final String id;
  final String title;
  final bool isComplete;
  final String? userId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'is_complete': isComplete,
      'user_id': userId,
    };
  }

  Todo copyWith({
    String? id,
    String? title,
    bool? isComplete,
    String? userId,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      isComplete: isComplete ?? this.isComplete,
      userId: userId ?? this.userId,
    );
  }
} 