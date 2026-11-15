import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://oreolag.github.io',
  base: '/cli',
  trailingSlash: 'always',
  integrations: [
    starlight({
      title: 'ODEV',
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/oreolag/cli' }],
      sidebar: [
        { label: 'Get started', slug: '' },
        { label: 'Installation', slug: 'installation' },
      ],
    }),
  ],
});
