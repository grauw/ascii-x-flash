type SerialCallback = (error?: unknown) => void;
const textDecoder = new TextDecoder();
const textEncoder = new TextEncoder();

export interface WritableSerialPort {
  on(event: 'data', listener: (chunk: Uint8Array) => void): void;
  on(event: 'error', listener: (error: Error) => void): void;
  on(event: 'close', listener: () => void): void;
  write(buffer: Uint8Array, callback: SerialCallback): unknown;
  drain(callback: SerialCallback): unknown;
}

interface ReadMatch<T> {
  value: T;
  rest: Uint8Array;
}

interface Waiter<T> {
  match: (buffer: Uint8Array) => ReadMatch<T> | undefined;
  resolve: (value: T) => void;
  reject: (error: Error) => void;
  timer: ReturnType<typeof setTimeout>;
}

export class SerialLine {
  private port: WritableSerialPort;
  private buffer: Uint8Array = new Uint8Array(0);
  private waiters: Waiter<unknown>[] = [];
  private closed = false;

  public constructor(port: WritableSerialPort) {
    this.port = port;

    port.on('data', (chunk) => this.push(chunk));
    port.on('error', (error) => this.fail(error));
    port.on('close', () => {
      this.closed = true;
      this.fail(new Error('Serial port closed'));
    });
  }

  public write(data: Uint8Array | string): Promise<void> {
    const buffer = typeof data == 'string' ? textEncoder.encode(data) : data;
    return new Promise((resolve, reject) => {
      this.port.write(buffer, (writeError) => {
        if (writeError) {
          reject(writeError);
          return;
        }
        this.port.drain((drainError) => drainError ? reject(drainError) : resolve());
      });
    });
  }

  public async readLine(timeoutMs = 30000): Promise<string> {
    const line = await this.readUntil((buffer) => {
      const cr = buffer.indexOf(0x0d);
      const lf = buffer.indexOf(0x0a);
      const indexes = [cr, lf].filter((index) => index >= 0);
      if (indexes.length == 0) {
        return undefined;
      }
      const end = Math.min(...indexes);
      let next = end + 1;
      while (next < buffer.length && (buffer[next] == 0x0d || buffer[next] == 0x0a)) {
        next++;
      }
      return {
        value: textDecoder.decode(buffer.subarray(0, end)).trim(),
        rest: buffer.subarray(next)
      };
    }, timeoutMs);

    return line.length == 0 ? this.readLine(timeoutMs) : line;
  }

  public readBytes(target: Uint8Array, timeoutMs = 30000): Promise<void> {
    return this.readUntil((buffer) => {
      if (buffer.length < target.length) {
        return undefined;
      }
      target.set(buffer.subarray(0, target.length));
      return {
        value: undefined,
        rest: buffer.subarray(target.length)
      };
    }, timeoutMs);
  }

  private push(chunk: Uint8Array): void {
    const buffer = new Uint8Array(this.buffer.length + chunk.length);
    buffer.set(this.buffer, 0);
    buffer.set(chunk, this.buffer.length);
    this.buffer = buffer;
    this.pump();
  }

  private fail(error: Error): void {
    const waiters = this.waiters.splice(0);
    for (const waiter of waiters) {
      clearTimeout(waiter.timer);
      waiter.reject(error);
    }
  }

  private readUntil<T>(match: (buffer: Uint8Array) => ReadMatch<T> | undefined, timeoutMs: number): Promise<T> {
    const immediate = match(this.buffer);
    if (immediate) {
      this.buffer = immediate.rest;
      return Promise.resolve(immediate.value);
    }
    if (this.closed) {
      return Promise.reject(new Error('Serial port closed'));
    }

    return new Promise((resolve, reject) => {
      const waiter: Waiter<T> = {
        match,
        resolve,
        reject,
        timer: setTimeout(() => {
          const index = this.waiters.indexOf(waiter as Waiter<unknown>);
          if (index >= 0) {
            this.waiters.splice(index, 1);
          }
          reject(new Error(`Timed out waiting for serial data after ${timeoutMs}ms`));
        }, timeoutMs)
      };
      this.waiters.push(waiter as Waiter<unknown>);
    });
  }

  private pump(): void {
    while (true) {
      const waiter = this.waiters[0];
      if (!waiter) {
        return;
      }
      const result = waiter.match(this.buffer);
      if (!result) {
        return;
      }
      this.waiters.shift();
      clearTimeout(waiter.timer);
      this.buffer = result.rest;
      waiter.resolve(result.value);
    }
  }
}
