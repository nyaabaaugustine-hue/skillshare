import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  images: { unoptimized: true },
  // A stray `C:\Users\TGNE\package-lock.json` makes Next walk up past this
  // project and adopt the whole home directory as the workspace root, which
  // drags unrelated files into output file tracing. Pin it here instead.
  outputFileTracingRoot: root,
};

export default nextConfig;
