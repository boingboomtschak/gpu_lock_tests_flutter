import 'dart:ffi';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:logcat_monitor/logcat_monitor.dart';

final gpulockLib = DynamicLibrary.open("libgpulock.so");
final gpulockRun = gpulockLib.lookupFunction<
    Pointer<Utf8> Function(Uint32, Uint32, Uint32, Uint32),
    Pointer<Utf8> Function(int, int, int, int)>('run');

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
  int _workgroups = 19;
  int _workgroupSize = 128;
  int _lockIters = 10000;
  int _testIters = 1000;
  String _workgroupsField = "";
  String _workgroupSizeField = "";
  String _lockItersField = "";
  String _testItersField = "";

  @override
  void initState() {
    super.initState();
    _workgroupsField = _workgroups.toString();
    _workgroupSizeField = _workgroupSize.toString();
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
    _workgroupSize = int.parse(_workgroupSizeField);
    _lockIters = int.parse(_lockItersField);
    _testIters = int.parse(_testItersField);
    final resultPtr =
        gpulockRun(_workgroups, _workgroupSize, _lockIters, _testIters);
    final result = resultPtr.toDartString();
    malloc.free(resultPtr);
    report = jsonDecode(result);
    JsonEncoder encoder = new JsonEncoder.withIndent('  ');
    print(encoder.convert(report));
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
              decoration: const InputDecoration(labelText: 'Workgroup Size'),
              keyboardType: TextInputType.number,
              initialValue: _workgroupSizeField,
              onChanged: (val) {
                _workgroupSizeField = val;
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
          Text('Lock failures (TAS fenced): ${report?['tas-failures-fenced']}'),
          Text(
              'Lock failure percent (TAS fenced): ${report?['tas-failure-percent-fenced']}%'),
          Text(
              'Test failures (TAS fenced): ${report?['tas-iter-failures-fenced']}'),
//          Text(
//              'Test average time (TAS fenced): ${report?['tas-test-avg-time-fenced']} seconds'),
//          Text(
//              'Test total time (TAS fenced): ${report?['tas-test-total-time-fenced']} seconds'),
          Text(
              'Lock failures (TAS unfenced): ${report?['tas-failures-unfenced']}'),
          Text(
              'Lock failure percent (TAS unfenced): ${report?['tas-failure-percent-unfenced']}%'),
          Text(
              'Test failures (TAS unfenced): ${report?['tas-iter-failures-unfenced']}'),
//          Text(
//              'Test average time (TAS unfenced): ${report?['tas-test-avg-time-unfenced']} seconds'),
//          Text(
//              'Test total time (TAS unfenced): ${report?['tas-test-total-time-unfenced']} seconds'),
          Text(
              'Lock failures (TTAS fenced): ${report?['ttas-failures-fenced']}'),
          Text(
              'Lock failure percent (TTAS fenced): ${report?['ttas-failure-percent-fenced']}%'),
          Text(
              'Test failures (TTAS fenced): ${report?['ttas-iter-failures-fenced']}'),
//          Text(
//              'Test average time (TTAS fenced): ${report?['ttas-test-avg-time-fenced']} seconds'),
//          Text(
//              'Test total time (TTAS fenced): ${report?['ttas-test-total-time-fenced']} seconds'),
          Text(
              'Lock failures (TTAS unfenced): ${report?['ttas-failures-unfenced']}'),
          Text(
              'Lock failure percent (TTAS unfenced): ${report?['ttas-failure-percent-unfenced']}%'),
          Text(
              'Test failures (TTAS unfenced): ${report?['ttas-iter-failures-unfenced']}'),
//          Text(
//              'Test average time (TTAS unfenced): ${report?['ttas-test-avg-time-unfenced']} seconds'),
//          Text(
//              'Test total time (TTAS unfenced): ${report?['ttas-test-total-time-unfenced']} seconds'),
          Text('Lock failures (CAS fenced): ${report?['cas-failures-fenced']}'),
          Text(
              'Lock failure percent (CAS fenced): ${report?['cas-failure-percent-fenced']}%'),
          Text(
              'Test failures (CAS fenced): ${report?['cas-iter-failures-fenced']}'),
          //         Text(
          //             'Test average time (CAS fenced): ${report?['cas-test-avg-time-fenced']} seconds'),
          //         Text(
          //             'Test total time (CAS fenced): ${report?['cas-test-total-time-fenced']} seconds'),
          Text(
              'Lock failures (CAS unfenced): ${report?['cas-failures-unfenced']}'),
          Text(
              'Lock failure percent (CAS unfenced): ${report?['cas-failure-percent-unfenced']}%'),
          Text(
              'Test failures (CAS unfenced): ${report?['cas-iter-failures-unfenced']}'),
//          Text(
//              'Test average time (CAS unfenced): ${report?['cas-test-avg-time-unfenced']} seconds'),
//          Text(
//              'Test total time (CAS unfenced): ${report?['cas-test-total-time-unfenced']} seconds'),
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
