import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/todo_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class TodoTestScreen extends StatefulWidget {
  const TodoTestScreen({Key? key}) : super(key: key);

  @override
  _TodoTestScreenState createState() => _TodoTestScreenState();
}

class _TodoTestScreenState extends State<TodoTestScreen> {
  List<Todo>? _todos;
  bool _loading = true;
  String? _errorMessage;
  final _titleController = TextEditingController();
  bool _isDisposed = false;
  
  @override
  void initState() {
    super.initState();
    _loadTodos();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _titleController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTodos() async {
    try {
      if (!mounted) return;
      
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
      
      final response = await Supabase.instance.client
          .from('todos')
          .select();
      
      final todos = (response as List)
          .map((item) => Todo.fromJson({
                'id': item['id'],
                'title': item['title'],
                'is_complete': item['is_complete'],
                'user_id': item['user_id'],
              }))
          .toList();
      
      if (!mounted) return;
      
      setState(() {
        _todos = todos;
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading todos: $e');
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'فشل في تحميل المهام: $e';
        _loading = false;
      });
    }
  }
  
  Future<void> _addTodo() async {
    if (_titleController.text.isEmpty) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال عنوان للمهمة')),
      );
      return;
    }
    
    try {
      if (!mounted) return;
      
      setState(() {
        _loading = true;
      });
      
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      await Supabase.instance.client.from('todos').insert({
        'title': _titleController.text,
        'is_complete': false,
        'user_id': userId,
      });
      
      _titleController.clear();
      await _loadTodos();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة المهمة بنجاح')),
      );
    } catch (e) {
      AppLogger.error('Error adding todo: $e');
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'فشل في إضافة المهمة: $e';
        _loading = false;
      });
    }
  }
  
  Future<void> _toggleTodoStatus(Todo todo) async {
    try {
      await Supabase.instance.client
          .from('todos')
          .update({'is_complete': !todo.isComplete})
          .eq('id', todo.id);
      
      await _loadTodos();
    } catch (e) {
      AppLogger.error('Error updating todo: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في تحديث حالة المهمة: $e')),
      );
    }
  }
  
  Future<void> _deleteTodo(String id) async {
    try {
      await Supabase.instance.client
          .from('todos')
          .delete()
          .eq('id', id);
      
      await _loadTodos();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المهمة بنجاح')),
      );
    } catch (e) {
      AppLogger.error('Error deleting todo: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في حذف المهمة: $e')),
      );
    }
  }
  
  Widget _buildTodosList() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTodos,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_todos == null || _todos!.isEmpty) {
      return const Center(
        child: Text('لا توجد مهام بعد. أضف مهمة جديدة!'),
      );
    }
    
    return ListView.builder(
      itemCount: _todos!.length,
      itemBuilder: (context, index) {
        final todo = _todos![index];
        return Dismissible(
          key: Key(todo.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _deleteTodo(todo.id),
          child: ListTile(
            title: Text(
              todo.title,
              style: TextStyle(
                decoration: todo.isComplete
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            trailing: Checkbox(
              value: todo.isComplete,
              onChanged: (_) => _toggleTodoStatus(todo),
            ),
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار Supabase قائمة المهام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodos,
          ),
        ],
      ),
      body: _buildTodosList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('إضافة مهمة جديدة'),
              content: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'عنوان المهمة',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addTodo().then((_) => Navigator.pop(context));
                  },
                  child: const Text('إضافة'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 