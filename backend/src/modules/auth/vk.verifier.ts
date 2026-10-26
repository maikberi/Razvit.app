export interface VkPayload {
  vkId: string;
  email: string | null;
  name: string;
}

/** Параметры, которые Flutter-клиент собирает после редиректа обратно от
 * VK ID (code/state/deviceId — из query адреса возврата, codeVerifier —
 * из PKCE-пары, которую клиент сгенерировал перед редиректом на VK,
 * см. core/auth/social_redirect_gateway.dart). */
export interface VkExchangeParams {
  code: string;
  deviceId: string;
  codeVerifier: string;
  redirectUri: string;
  state: string;
}

/** Абстракция вокруг обмена кода VK ID на данные пользователя — позволяет
 * подменить в тестах, не обращаясь к настоящим серверам VK. */
export interface VkAuthVerifier {
  exchangeCode(params: VkExchangeParams): Promise<VkPayload | null>;
}

interface VkTokenResponse {
  access_token?: string;
  user_id?: number;
  state?: string;
}

interface VkUserInfoResponse {
  user?: {
    user_id?: string | number;
    first_name?: string;
    last_name?: string;
    email?: string;
  };
}

/**
 * VK ID (id.vk.ru) — текущий протокол авторизации VK, OAuth 2.1 + PKCE
 * (сменил классический oauth.vk.com, который отклоняет запросы от
 * приложений, зарегистрированных через новую панель id.vk.com — см.
 * https://id.vk.ru/about/business/go/docs/ru/vkid/latest/vk-id/connection/api-description).
 * Наше приложение "конфиденциальное" (есть свой backend), поэтому обмен
 * кода на токен идёт на бэкенде и требует ещё и service_token —
 * "Сервисный ключ доступа" из настроек приложения (НЕ "Защищённый ключ" —
 * это разные вещи, VK ID использует именно сервисный).
 */
export class RealVkAuthVerifier implements VkAuthVerifier {
  constructor(
    private readonly clientId: string,
    private readonly serviceToken: string,
  ) {}

  async exchangeCode({ code, deviceId, codeVerifier, redirectUri, state }: VkExchangeParams): Promise<VkPayload | null> {
    const tokenRes = await fetch('https://id.vk.ru/oauth2/auth', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        code_verifier: codeVerifier,
        redirect_uri: redirectUri,
        client_id: this.clientId,
        device_id: deviceId,
        state,
        service_token: this.serviceToken,
      }),
    });
    if (!tokenRes.ok) return null;
    const tokenJson = (await tokenRes.json()) as VkTokenResponse;
    if (!tokenJson.access_token || !tokenJson.user_id) return null;
    // VK эхом возвращает переданный state вместе с токеном — сверяем ещё
    // раз на бэкенде (клиент уже проверил его сразу после редиректа).
    if (tokenJson.state !== undefined && tokenJson.state !== state) return null;

    const userRes = await fetch('https://id.vk.ru/oauth2/user_info', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: this.clientId,
        access_token: tokenJson.access_token,
      }),
    });
    if (!userRes.ok) return null;
    const userJson = (await userRes.json()) as VkUserInfoResponse;
    const user = userJson.user;
    if (!user) return null;

    return {
      vkId: String(user.user_id ?? tokenJson.user_id),
      email: user.email ?? null,
      name: [user.first_name, user.last_name].filter(Boolean).join(' ').trim(),
    };
  }
}
