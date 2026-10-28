import 'dart:io';

/// Reads an environment variable (VM test runs).
String? readEnv(String name) => Platform.environment[name];
