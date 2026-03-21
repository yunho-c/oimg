import 'package:flutter/material.dart';
import 'package:oimg/src/rust/api/simple.dart';
import 'package:oimg/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final greeting = greet(name: 'oimg');

    return MaterialApp(
      title: 'oimg',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('oimg')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              Text(
                'Flutter + Rust Bridge',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(greeting, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
