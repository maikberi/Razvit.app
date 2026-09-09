import 'dart:html' as html;

void navigateTo(String url) {
  html.window.location.href = url;
}

/// Убирает query (?code=...) из адресной строки, не трогая остальную
/// историю — иначе обновление страницы после входа через VK повторно
/// "приходило" бы с тем же (уже использованным) кодом.
void clearBootQuery() {
  html.window.history.replaceState(null, '', html.window.location.pathname);
}

const _pkceCodeVerifierKey = 'vk_pkce_code_verifier';
const _pkceStateKey = 'vk_pkce_state';

/// sessionStorage переживает полноэкранный редирект на VK и обратно (в
/// отличие от состояния в памяти Dart, которое сбрасывается при
/// перезагрузке страницы), но не переживает закрытие вкладки — этого
/// достаточно, PKCE-пара нужна только на время одного захода на VK.
void savePkce({required String codeVerifier, required String state}) {
  html.window.sessionStorage[_pkceCodeVerifierKey] = codeVerifier;
  html.window.sessionStorage[_pkceStateKey] = state;
}

({String? codeVerifier, String? state}) readAndClearPkce() {
  final codeVerifier = html.window.sessionStorage[_pkceCodeVerifierKey];
  final state = html.window.sessionStorage[_pkceStateKey];
  html.window.sessionStorage.remove(_pkceCodeVerifierKey);
  html.window.sessionStorage.remove(_pkceStateKey);
  return (codeVerifier: codeVerifier, state: state);
}
