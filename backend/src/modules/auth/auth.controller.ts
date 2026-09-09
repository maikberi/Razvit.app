import { asyncHandler } from '../../utils/asyncHandler';
import { AuthService } from './auth.service';
import { GoogleAuthBody, LoginBody, RegisterBody } from './auth.validation';

export class AuthController {
  constructor(private readonly service: AuthService) {}

  register = asyncHandler(async (req, res) => {
    const body = req.validatedBody as RegisterBody;
    const result = await this.service.register(body.email, body.password, body.name);
    res.status(201).json({ data: result });
  });

  login = asyncHandler(async (req, res) => {
    const body = req.validatedBody as LoginBody;
    const result = await this.service.login(body.email, body.password);
    res.status(200).json({ data: result });
  });

  google = asyncHandler(async (req, res) => {
    const body = req.validatedBody as GoogleAuthBody;
    const result = await this.service.loginWithGoogle(body.idToken);
    res.status(200).json({ data: result });
  });

  me = asyncHandler(async (req, res) => {
    const user = await this.service.me(req.userId as string);
    if (!user) {
      res.status(404).json({ error: { code: 'USER_NOT_FOUND', message: 'Пользователь не найден' } });
      return;
    }
    res.status(200).json({ data: user });
  });
}
