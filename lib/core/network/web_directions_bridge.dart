//**********************************************
// Platform-Conditional Web JS Directions API  *
//**********************************************

export 'web_directions_bridge_stub.dart'
    if (dart.library.js_interop) 'web_directions_bridge_web.dart';
