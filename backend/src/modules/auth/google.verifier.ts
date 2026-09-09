import { OAuth2Client } from 'google-auth-library';

export interface GooglePayload {
  googleId: string;
  email: string;
  name: string;
}

/** Абстракция вокруг проверки Google id-токена — позволяет подменить
 * реализацию в тестах, не обращаясь к настоящим серверам Google. */
export interface GoogleTokenVerifier {
  verify(idToken: string): Promise<GooglePayload | null>;
}

export class RealGoogleTokenVerifier implements GoogleTokenVerifier {
  private readonly client: OAuth2Client;

  constructor(private readonly clientId: string) {
    this.client = new OAuth2Client(clientId);
  }

  async verify(idToken: string): Promise<GooglePayload | null> {
    const ticket = await this.client.verifyIdToken({ idToken, audience: this.clientId });
    const payload = ticket.getPayload();
    if (!payload?.sub || !payload.email) return null;
    return { googleId: payload.sub, email: payload.email, name: payload.name ?? payload.email };
  }
}
