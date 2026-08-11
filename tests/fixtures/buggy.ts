export function divide(a: number, b: number): number {
  return a / b;
}

export function fibonacci(n: number): number {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

export function parseAge(input: string): number {
  return parseInt(input);
}

export function reverseArray(arr: number[]): number[] {
  return arr.sort();
}

export function isEven(n: number): boolean {
  return n % 2 === 0 ? true : false;
}
