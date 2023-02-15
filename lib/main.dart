import 'dart:ffi';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:logcat_monitor/logcat_monitor.dart';

final gpulockLib = DynamicLibrary.open("libgpulock.so");
final Pointer<Utf8> Function(int, int, int) gpulockRun =
    gpulockLib.lookupFunction<Pointer<Utf8> Function(Uint32, Uint32, Uint32),
        Pointer<Utf8> Function(int, int, int)>('run');

Map<String, dynamic>? report;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPU Lock Tests',
      theme: ThemeData(
        primarySwatch: Colors.red,
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
  final StringBuffer _logBuffer = StringBuffer("");
  int _workgroups = 8;
  int _lockIters = 10000;
  int _testIters = 16;
  String _workgroupsField = "";
  String _lockItersField = "";
  String _testItersField = "";

  @override
  void initState() {
    super.initState();
    _workgroupsField = _workgroups.toString();
    _lockItersField = _lockIters.toString();
    _testItersField = _testIters.toString();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    LogcatMonitor.clearLogcat;
    try {
      LogcatMonitor.addListen(_listenStream);
    } on PlatformException {
      debugPrint('Failed to listen Stream of log.');
    }
    await LogcatMonitor.startMonitor("GPULockTests:* *:S");
  }

  void _listenStream(dynamic value) {
    if (value is String) {
      if (mounted) {
        setState(() {
          _logBuffer.writeln(value);
        });
      } else {
        _logBuffer.writeln(value);
      }
    }
  }

  void _runTests() {
    clearLog();
    _workgroups = int.parse(_workgroupsField);
    _lockIters = int.parse(_lockItersField);
    _testIters = int.parse(_testItersField);
    final resultPtr = gpulockRun(_workgroups, _lockIters, _testIters);
    final result = resultPtr.toDartString();
    malloc.free(resultPtr);
    report = jsonDecode(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
              decoration: const InputDecoration(labelText: 'Workgroups'),
              keyboardType: TextInputType.number,
              initialValue: _workgroupsField,
              onChanged: (val) {
                _workgroupsField = val;
              }),
          TextFormField(
              decoration:
                  const InputDecoration(labelText: 'Lock attempts per thread'),
              keyboardType: TextInputType.number,
              initialValue: _lockItersField,
              onChanged: (val) {
                _lockItersField = val;
              }),
          TextFormField(
              decoration:
                  const InputDecoration(labelText: 'Number of tests per lock'),
              keyboardType: TextInputType.number,
              initialValue: _testItersField,
              onChanged: (val) {
                _testItersField = val;
              }),
          Divider(color: Colors.black),
          Text('Report', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('OS: ${report?['os-name']}'),
          Text('GPU Name: ${report?['device-name']}'),
          Text('GPU Type: ${report?['device-type']}'),
          Text('Workgroups: ${report?['workgroups']}'),
          Text('Lock attempts per thread: ${report?['lock-iters']}'),
          Text('Number of tests per lock: ${report?['test-iters']}'),
          Text('Total lock attempts per lock: ${report?['total-locks']}'),
          Text('Lock failures (TAS): ${report?['tas-failures']}'),
          Text(
              'Lock failure percent (TAS): ${report?['tas-failure-percent']}%'),
          Text('Lock failures (TAS fenced): ${report?['tas-fenced-failures']}'),
          Text(
              'Lock failure percent (TAS fenced): ${report?['tas-fenced-failure-percent']}%'),
          Text('Lock failures (TTAS): ${report?['ttas-failures']}'),
          Text(
              'Lock failure percent (TTAS): ${report?['ttas-failure-percent']}%'),
          Text(
              'Lock failures (TTAS fenced): ${report?['ttas-fenced-failures']}'),
          Text(
              'Lock failure percent (TTAS fenced): ${report?['ttas-fenced-failure-percent']}%'),
          Text('Lock failures (CAS): ${report?['cas-failures']}'),
          Text(
              'Lock failure percent (CAS): ${report?['cas-failure-percent']}%'),
          Text('Lock failures (CAS fenced): ${report?['cas-fenced-failures']}'),
          Text(
              'Lock failure percent (CAS fenced): ${report?['cas-fenced-failure-percent']}%'),
          Divider(color: Colors.black),
          logboxBuild(context)
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _runTests,
        tooltip: 'Run Tests',
        child: const Icon(Icons.trending_flat),
      ),
    );
  }

  Widget logboxBuild(BuildContext context) {
    return Expanded(
      child: Center(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(
              color: Colors.blueAccent,
              width: 1.0,
            ),
          ),
          child: Scrollbar(
            thickness: 10,
            radius: Radius.circular(20),
            child: SingleChildScrollView(
              reverse: true,
              scrollDirection: Axis.vertical,
              child: Text(
                _logBuffer.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void clearLog() async {
    LogcatMonitor.clearLogcat;
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      _logBuffer.clear();
    });
  }
}
