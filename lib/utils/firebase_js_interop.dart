@JS()
library;

import 'package:js/js.dart';
import 'dart:async';

@JS('Promise')
class PromiseJsImpl<T> {
  external PromiseJsImpl(
      void Function(void Function(T) resolve, void Function(dynamic) reject)
          executor);
  external PromiseJsImpl<S> then<S>(dynamic Function(T) onFulfilled,
      [Function? onRejected]);
  external PromiseJsImpl<T> catchError(Function onRejected);
}

@JS()
@anonymous
class JSError {
  external factory JSError();
  external String get name;
  external String get message;
  external String get stack;
}

Future<T> handleThenable<T>(PromiseJsImpl<T> promise) {
  final completer = Completer<T>();
  promise
      .then<T>(allowInterop((value) => completer.complete(value)))
      .catchError(
          allowInterop((error) => completer.completeError(error as Object)));
  return completer.future;
}

Future<T> promiseToFuture<T>(PromiseJsImpl<T> promise) {
  return handleThenable(promise);
}
