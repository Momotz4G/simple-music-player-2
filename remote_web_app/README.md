# 🌐 Remote Web App Configuration

This directory contains the static remote control web application that allows users to interact with the music player, queue songs, and view playback states from any device.

To connect this remote application to your custom backend, you must configure the PocketBase server URL.

---

## 🛠️ Setup Instructions

The configuration file `config.js` is **git-ignored** to prevent exposing private server URLs. To set it up for your server:

1. **Create the Configuration File:**
   In this directory (`remote_web_app/`), create a new file named **`config.js`**.

2. **Add Your Server URL:**
   Paste the following code into your new `config.js` file, replacing `https://your-pocketbase-server.com` with your active PocketBase backend URL:

   ```javascript
   // 🚀 SERVER CONFIGURATION
   // This file is git-ignored. Change this safely on your deployment server.

   window.POCKETBASE_CONFIG = {
       url: "https://your-pocketbase-server.com"
   };
   ```

3. **Deploy the Web App:**
   Upload the `remote_web_app` folder (containing `index.html`, `README.md`, and your configured `config.js`) to any static file hosting service (e.g., Vercel, Netlify, GitHub Pages, or your own VPS).

---

## 🔒 Security Best Practice

Never commit your actual `config.js` with your production backend URL to public repositories. The root `.gitignore` is already pre-configured to keep `remote_web_app/config.js` hidden.
