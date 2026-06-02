#!/usr/bin/env node

import { CLI } from './asciixf-player/CLI.ts';

const cli = new CLI(process.argv.slice(2));

cli.run().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
