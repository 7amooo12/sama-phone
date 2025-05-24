import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/app_localizations.dart';

class AppErrorWidget extends StatelessWidget {
  final String? message;
  final Function? onRetry;

  const AppErrorWidget({
    Key? key,
    this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            message ?? appLocalizations.translate('error_occurred') ?? 'حدث خطأ ما',
            style: const TextStyle(
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => onRetry!(),
              child: Text(appLocalizations.translate('retry') ?? 'إعادة المحاولة'),
            ),
          ],
        ],
      ),
    );
  }
} 