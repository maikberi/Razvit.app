export interface VkPayload {
  vkId: string;
  email: string | null;
  name: string;
}

/** Абстракция вокруг обмена кода VK на данные пользователя — позволяет
 * подменить в тестах, не обращаясь к настоящим серверам VK. */
export interface VkAuthVerifier {
  exchangeCode(code: string, redirectUri: string): Promise<VkPayload | null>;
}

const VK_API_VERSION = '5.199';

export class RealVkAuthVerifier implements VkAuthVerifier {
  constructor(
    private readonly clientId: string,
    private readonly clientSecret: string,
  ) {}

  async exchangeCode(code: string, redirectUri: string): Promise<VkPayload | null> {
    const tokenUrl = new URL('https://oauth.vk.com/access_token');
    tokenUrl.searchParams.set('client_id', this.clientId);
    tokenUrl.searchParams.set('client_secret', this.clientSecret);
    tokenUrl.searchParams.set('redirect_uri', redirectUri);
    tokenUrl.searchParams.set('code', code);

    const tokenRes = await fetch(tokenUrl);
    if (!tokenRes.ok) return null;
    const tokenJson = (await tokenRes.json()) as { access_token?: string; user_id?: number; email?: string };
    if (!tokenJson.access_token || !tokenJson.user_id) return null;

    const usersUrl = new URL('https://api.vk.com/method/users.get');
    usersUrl.searchParams.set('user_ids', String(tokenJson.user_id));
    usersUrl.searchParams.set('fields', 'first_name,last_name');
    usersUrl.searchParams.set('access_token', tokenJson.access_token);
    usersUrl.searchParams.set('v', VK_API_VERSION);

    const usersRes = await fetch(usersUrl);
    if (!usersRes.ok) return null;
    const usersJson = (await usersRes.json()) as { response?: Array<{ first_name: string; last_name: string }> };
    const person = usersJson.response?.[0];
    if (!person) return null;

    const vkId = String(tokenJson.user_id);
    return {
      vkId,
      email: tokenJson.email ?? null,
      name: `${person.first_name} ${person.last_name}`.trim(),
    };
  }
}
