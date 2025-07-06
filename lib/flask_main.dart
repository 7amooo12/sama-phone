import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/flask_providers.dart';
import 'package:smartbiztracker_new/screens/flask_login_screen.dart';
import 'package:smartbiztracker_new/screens/flask_products_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlaskAppIntegration());
}

class FlaskAppIntegration extends StatelessWidget {
  const FlaskAppIntegration({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FlaskAuthProvider()),
        ChangeNotifierProvider(create: (_) => FlaskProductsProvider()),
        ChangeNotifierProvider(create: (_) => FlaskInvoicesProvider()),
      ],
      child: Consumer<FlaskAuthProvider>(
        builder: (context, authProvider, _) {
          // Initialize the auth provider if not already done
          if (!authProvider.isInitialized) {
            authProvider.initialize();
          }

          return MaterialApp(
            title: 'SAMA متجر',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.deepPurple,
              fontFamily: 'Cairo',
              textTheme: Theme.of(context).textTheme.apply(
                    fontFamily: 'Cairo',
                  ),
            ),
            // Add Arabic localization support
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ar', ''),
              Locale('en', ''),
            ],
            locale: const Locale('ar', ''),
            // Define routes
            initialRoute: authProvider.isAuthenticated ? '/products' : '/login',
            routes: {
              '/login': (context) => const FlaskLoginScreen(),
              '/products': (context) => const FlaskProductsScreen(),
            },
            // Handle unknown routes
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const FlaskProductsScreen(),
              );
            },
          );
        },
      ),
    );
  }
} 