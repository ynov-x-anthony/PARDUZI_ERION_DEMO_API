'use strict';

// notifier : simule l'envoi d'une notif (mail, slack...) quand un produit est cree.
// Il connait rien de l'api, il expose juste POST /notify.

const express = require('express');

const PORT = Number(process.env.PORT || 4000);

const app = express();
app.use(express.json());

app.get('/health', (req, res) => res.json({ status: 'UP' }));

app.post('/notify', (req, res) => {
  console.log(`[notifier] nouveau produit : ${JSON.stringify(req.body)}`);
  res.status(202).json({ received: true });
});

const server = app.listen(PORT, () => {
  console.log(`[notifier] demarre sur le port ${PORT}`);
});

// arret propre sur docker stop
process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));
