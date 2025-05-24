// Flutter Bootstrap JS
// This script ensures Firebase initialization completes before loading Flutter

document.addEventListener('DOMContentLoaded', function() {
  // Load the Flutter app's main.dart.js
  const scriptTag = document.createElement('script');
  scriptTag.src = 'main.dart.js';
  scriptTag.type = 'application/javascript';
  document.body.appendChild(scriptTag);
  
  // Add Promise/Firebase compatibility shims
  if (!window.PromiseJsImpl) {
    window.PromiseJsImpl = Promise;
  }
  
  if (!window.handleThenable) {
    window.handleThenable = function(thenable) {
      return Promise.resolve(thenable);
    };
  }
  
  console.log('Flutter bootstrap initialized');
});