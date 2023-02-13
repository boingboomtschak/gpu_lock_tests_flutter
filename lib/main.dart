import 'package:flutter/material.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

final gpulockLib = DynamicLibrary.open("libgpulock.so");
final Pointer<Utf8> Function() gpulockRun = gpulockLib
    .lookup<NativeFunction<Pointer<Utf8> Function()>>('run')
    .asFunction();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPU Lock Tests',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'GPU Lock Tests'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String _resultBuffer = "< Not yet run >";

  void _runTests() {
    setState(() {
      _resultBuffer = "Running...";
    });
    final resultPtr = gpulockRun();
    final result = resultPtr.toDartString();
    malloc.free(resultPtr);
    setState(() {
      _resultBuffer = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '$_resultBuffer',
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _runTests,
        tooltip: 'Run Tests',
        child: const Icon(Icons.trending_flat),
      ),
    );
  }
}
