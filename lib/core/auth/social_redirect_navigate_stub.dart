void navigateTo(String url) {
  throw UnsupportedError('Редирект на страницу провайдера доступен только в вебе.');
}

void clearBootQuery() {}

void savePkce({required String codeVerifier, required String state}) {}

({String? codeVerifier, String? state}) readAndClearPkce() => (codeVerifier: null, state: null);
