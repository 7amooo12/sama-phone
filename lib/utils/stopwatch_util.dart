// Custom utility class to replace the stop_watch package
// This provides the same functionality but uses Dart's built-in Stopwatch

class StopWatch {
  final Stopwatch _stopwatch = Stopwatch();
  
  StopWatch();
  
  void start() {
    _stopwatch.start();
  }
  
  void stop() {
    _stopwatch.stop();
  }
  
  void reset() {
    _stopwatch.reset();
  }
  
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;
  
  int get elapsedMicroseconds => _stopwatch.elapsedMicroseconds;
  
  double get elapsedSeconds => _stopwatch.elapsedMilliseconds / 1000.0;
  
  bool get isRunning => _stopwatch.isRunning;
} 