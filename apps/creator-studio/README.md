# DarkVibeX Creator Studio

Creator Studio is built from this folder and published as static assets by the existing `darkvibex-api` Cloudflare Worker.

## Local development

```sh
npm install
npm run dev
```

## Deployment

The GitHub Actions workflow builds this Vite app into `apps/owner_panel/creator-studio/` before `wrangler deploy`. Because that folder is inside the Worker `ASSETS` directory, it is served at:

`https://darkvibex-api.mishrajii7991.workers.dev/creator-studio/`

The Owner Panel links to Creator Studio while keeping the same browser tab/session. Creator Studio reads the active `dvxOwnerToken` from session storage on the same origin; it never stores the token in local storage. Upload/publish remains gated by the Worker Owner Panel API permission checks, and binary assets are stored in the `darkvibex-files` R2 bucket by the Worker.

No AppDeploy AI endpoint or paid AI credits are used by this standalone build. Prompt-to-design behavior is implemented in the browser/editor.

Cloudflare deployment still depends on the repository's configured `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` Actions secrets. The deployment workflow checks the published Creator Studio HTML and JavaScript bundle after deployment.
