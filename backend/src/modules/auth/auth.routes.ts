import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { validate } from '../../middleware/validate';
import { AuthController } from './auth.controller';
import { AuthRepository } from './auth.repository';
import { AuthService } from './auth.service';
import { googleAuthSchema, loginSchema, registerSchema } from './auth.validation';

const repository = new AuthRepository(pool);
const service = new AuthService(repository);
const controller = new AuthController(service);

export const authRouter = Router();

authRouter.post('/auth/register', validate(registerSchema, 'body'), controller.register);
authRouter.post('/auth/login', validate(loginSchema, 'body'), controller.login);
authRouter.post('/auth/google', validate(googleAuthSchema, 'body'), controller.google);
authRouter.get('/auth/me', authUser, controller.me);

export { AuthRepository, AuthService };
