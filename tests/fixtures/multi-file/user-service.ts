export interface User {
  id: number;
  name: string;
  email: string;
  createdAt: string;
}

export class UserService {
  private users: User[] = [];
  private nextId = 1;

  createUser(name: string, email: string): User {
    const user: User = {
      id: this.nextId++,
      name,
      email,
      createdAt: new Date().toISOString(),
    };
    this.users.push(user);
    return user;
  }

  listUsers(): User[] {
    return this.users;
  }

  findById(id: number): User | undefined {
    return this.users.find(u => u.id === id);
  }

  deleteUser(id: number): boolean {
    const idx = this.users.findIndex(u => u.id === id);
    if (idx === -1) return false;
    this.users.splice(idx, 1);
    return true;
  }
}
