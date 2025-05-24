import 'package:flutter/material.dart';

// General placeholder screen
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  
  const PlaceholderScreen({
    Key? key,
    required this.title,
    this.message = 'هذه الصفحة قيد التطوير',
    this.icon = Icons.construction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 80,
                color: Theme.of(context).primaryColor.withOpacity(0.7),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Product related placeholders
class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المنتج'),
      ),
      body: Center(
        child: Text('تفاصيل المنتج: $productId'),
      ),
    );
  }
}

class AddProductScreen extends StatelessWidget {
  const AddProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة منتج'),
      ),
      body: const Center(
        child: Text('نموذج إضافة منتج جديد'),
      ),
    );
  }
}

class EditProductScreen extends StatelessWidget {
  const EditProductScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل المنتج'),
      ),
      body: Center(
        child: Text('تعديل المنتج: $productId'),
      ),
    );
  }
}

// Orders related placeholders
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات'),
      ),
      body: const Center(
        child: Text('قائمة الطلبات'),
      ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
      ),
      body: Center(
        child: Text('تفاصيل الطلب: $orderId'),
      ),
    );
  }
}

class CreateOrderScreen extends StatelessWidget {
  const CreateOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء طلب جديد'),
      ),
      body: const Center(
        child: Text('نموذج إنشاء طلب جديد'),
      ),
    );
  }
}

// Fault related placeholders
class FaultsScreen extends StatelessWidget {
  const FaultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأعطال'),
      ),
      body: const Center(
        child: Text('قائمة الأعطال'),
      ),
    );
  }
}

class FaultDetailsScreen extends StatelessWidget {
  const FaultDetailsScreen({super.key, required this.faultId});
  final String faultId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العطل'),
      ),
      body: Center(
        child: Text('تفاصيل العطل: $faultId'),
      ),
    );
  }
}

class ReportFaultScreen extends StatelessWidget {
  const ReportFaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإبلاغ عن عطل'),
      ),
      body: const Center(
        child: Text('نموذج الإبلاغ عن عطل'),
      ),
    );
  }
}

// Returns related placeholders
class ReturnsScreen extends StatelessWidget {
  const ReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المرتجعات'),
      ),
      body: const Center(
        child: Text('قائمة المرتجعات'),
      ),
    );
  }
}

class ReturnDetailsScreen extends StatelessWidget {
  const ReturnDetailsScreen({super.key, required this.returnId});
  final String returnId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المرتجع'),
      ),
      body: Center(
        child: Text('تفاصيل المرتجع: $returnId'),
      ),
    );
  }
}

class CreateReturnScreen extends StatelessWidget {
  const CreateReturnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء مرتجع'),
      ),
      body: const Center(
        child: Text('نموذج إنشاء مرتجع'),
      ),
    );
  }
}

// Productivity related placeholders
class ProductivityDetailsScreen extends StatelessWidget {
  const ProductivityDetailsScreen({super.key, required this.productivityId});
  final String productivityId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الإنتاجية'),
      ),
      body: Center(
        child: Text('تفاصيل الإنتاجية: $productivityId'),
      ),
    );
  }
}

class AddProductivityScreen extends StatelessWidget {
  const AddProductivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة إنتاجية'),
      ),
      body: const Center(
        child: Text('نموذج إضافة إنتاجية'),
      ),
    );
  }
}
