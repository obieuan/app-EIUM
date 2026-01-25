import 'dart:html' as html;

const _fragmentKey = 'auth_fragment';

String? readStoredAuthFragment() => html.window.localStorage[_fragmentKey];

void clearStoredAuthFragment() {
  html.window.localStorage.remove(_fragmentKey);
}
