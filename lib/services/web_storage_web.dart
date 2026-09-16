// Web implementation — uses browser sessionStorage to survive the OAuth redirect.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void webStorageSet(String key, String value) =>
    html.window.sessionStorage[key] = value;

String? webStorageGet(String key) => html.window.sessionStorage[key];

void webStorageRemove(String key) => html.window.sessionStorage.remove(key);
