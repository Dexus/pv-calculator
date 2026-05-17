// Tell vitest-pool-workers what `env` looks like in tests so `import { env }
// from 'cloudflare:test'` resolves to a typed value backed by wrangler.toml.
declare module 'cloudflare:test' {
  interface ProvidedEnv extends Env {}
}

import type { Env } from '../src/types';
