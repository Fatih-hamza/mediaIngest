const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const LOG_PATH = '/var/log/media-ingest.log';
const PORT = process.env.PORT || 3000;

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/logs', (req, res) => {
  fs.readFile(LOG_PATH, 'utf8', (err, data) => {
    if (err) {
      return res.json({ ok: false, logs: `Could not read ${LOG_PATH}: ${err.message}` });
    }
    const lines = data.split(/\r?\n/);
    const tail = lines.slice(-200).join('\n');
    res.json({ ok: true, logs: tail });
  });
});

app.get('/api/status', (req, res) => {
  // Check for running rsync processes using pgrep
  exec('pgrep -x rsync', (err, stdout) => {
    const running = !!stdout && stdout.toString().trim().length > 0;
    res.json({ ok: true, syncing: running });
  });
});

// If the client has been built, serve it from client/dist
const clientDist = path.join(__dirname, 'client', 'dist');
if (fs.existsSync(clientDist)) {
  app.use(express.static(clientDist));
  app.get('*', (req, res) => res.sendFile(path.join(clientDist, 'index.html')));
}

app.listen(PORT, () => {
  console.log(`Media Ingest Monitor server listening on port ${PORT}`);
});
