# Universal Media Ingest — Monitor

This project provides a simple Node/Express backend and a Vite + React frontend for monitoring a media ingest process (rsync) on a Linux host.

Quick start

1. Install backend deps and start server (runs on port 3000):

```bash
cd /home/spooky/Desktop/copyMontior
npm install
npm start
```

2. In a separate terminal, start the frontend (dev mode):

```bash
cd /home/spooky/Desktop/copyMontior/client
npm install
npm run dev
```

The frontend (Vite) will proxy to `/api/*` on the same host — in production you can build the client and serve `client/dist` from the Express server.

Endpoints

- `GET /api/logs` — returns last 200 lines of `/var/log/media-ingest.log`.
- `GET /api/status` — returns `{ syncing: true|false }` depending on whether `rsync` is running.
