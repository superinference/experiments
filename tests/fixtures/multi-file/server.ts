import { UserService } from './user-service';

export class Server {
  private userService: UserService;
  private port: number;

  constructor(port: number) {
    this.port = port;
    this.userService = new UserService();
  }

  handleRequest(path: string, body?: Record<string, unknown>): { status: number; data: unknown } {
    if (path === '/users' && body) {
      const user = this.userService.createUser(body.name as string, body.email as string);
      return { status: 201, data: user };
    }
    if (path === '/users') {
      return { status: 200, data: this.userService.listUsers() };
    }
    return { status: 404, data: { error: 'Not found' } };
  }
}
