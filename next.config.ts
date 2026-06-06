import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // output: "standalone", // disabled for local development
  /* config options here */
  typescript: {
    ignoreBuildErrors: true,
  },
  reactStrictMode: false,
  allowedDevOrigins: ['127.0.2.2', 'localhost'],
};

export default nextConfig;
