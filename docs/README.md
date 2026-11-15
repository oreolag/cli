# Documentation website

The Starlight site is published at https://oreolag.github.io/cli/.

From this directory:

```sh
npm ci
npm run dev
```

Edit pages in `src/content/docs/`. The two initial pages intentionally contain
only titles. Existing Markdown guides elsewhere in this directory are not yet
part of the website.

Run `npm run build` to check the production build. Pull requests to `main` also
build the site; changes merged into `main` deploy through `.github/workflows/docs.yml`.
GitHub Pages must use **GitHub Actions** as its source in repository settings.
