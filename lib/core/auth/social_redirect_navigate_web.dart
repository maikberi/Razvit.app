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
