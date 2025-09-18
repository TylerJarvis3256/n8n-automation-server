
```
# Puppeteer Setup for n8n

## Overview
This document provides complete instructions for adding Puppeteer/Chromium web scraping capabilities to n8n using a custom Docker image. This setup enables automated web scraping for job boards and other JavaScript-heavy sites directly within n8n workflows.

## Prerequisites
- Docker and Docker Compose installed
- n8n-docker-caddy repository cloned
- Domain configured with DNS pointing to server
- .env file configured with all required variables

## Complete Setup Instructions

### 1. Create the Dockerfile
Create a file named `Dockerfile` in your n8n-docker-caddy directory with this exact content:

```dockerfile
# Custom n8n image with Puppeteer support
FROM n8nio/n8n:latest

# Switch to root to install dependencies
USER root

# Install Chromium and dependencies for Puppeteer
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    nodejs \
    yarn

# Tell Puppeteer to use installed Chromium instead of downloading
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Create a directory for custom node modules
RUN mkdir -p /home/node/custom_modules

# Install Puppeteer in a custom location to avoid conflicts
WORKDIR /home/node/custom_modules
RUN npm init -y && \
    npm install puppeteer@21.0.0 puppeteer-core@21.0.0 puppeteer-extra@3.3.6 puppeteer-extra-plugin-stealth@2.11.2

# Set NODE_PATH to include our custom modules
ENV NODE_PATH=/home/node/custom_modules/node_modules:/usr/local/lib/node_modules/n8n/node_modules

# Switch back to node user
USER node

# Set Chrome binary path for Puppeteer
ENV CHROME_BIN=/usr/bin/chromium-browser \
    CHROME_PATH=/usr/bin/chromium-browser

# Reset working directory
WORKDIR /home/node

# Verify installation (simplified check)
RUN echo "Chromium installed at:" && ls -la /usr/bin/chromium-browser && \
    echo "Puppeteer modules installed at:" && ls -la /home/node/custom_modules/node_modules/ | grep puppeteer
```

### 2. Build the Custom Image
```bash
# Build the custom n8n image with Puppeteer
sudo docker build -t n8n-puppeteer:latest .
```

### 3. Update docker-compose.yml
Modify the n8n service in your docker-compose.yml:

```yaml
n8n:
  image: n8n-puppeteer:latest  # Changed from n8nio/n8n
  restart: always
  ports:
    - 5678:5678
  environment:
    - N8N_HOST=${SUBDOMAIN}.${DOMAIN_NAME}
    - N8N_PORT=5678
    - N8N_PROTOCOL=https
    - NODE_ENV=production
    - WEBHOOK_URL=https://${SUBDOMAIN}.${DOMAIN_NAME}/
    - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
    - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
    - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
    - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
    - DB_TYPE=${DB_TYPE}
    - DB_POSTGRESDB_DATABASE=${DB_POSTGRESDB_DATABASE}
    - DB_POSTGRESDB_HOST=${DB_POSTGRESDB_HOST}
    - DB_POSTGRESDB_PORT=${DB_POSTGRESDB_PORT}
    - DB_POSTGRESDB_USER=${DB_POSTGRESDB_USER}
    - DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}
    - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    - NODE_FUNCTION_ALLOW_BUILTIN=*
    - NODE_FUNCTION_ALLOW_EXTERNAL=*
  volumes:
    - n8n_data:/home/node/.n8n
    - ${DATA_FOLDER}/local_files:/files
  depends_on:
    - postgres
```

### 4. Create Required Docker Volumes
```bash
sudo docker volume create caddy_data
sudo docker volume create n8n_data
sudo docker volume create postgres_data
```

### 5. Start Services
```bash
# Stop any existing containers
sudo docker compose down

# Start services with new image
sudo docker compose up -d

# Verify all services are running
sudo docker compose ps

# Check logs for errors
sudo docker compose logs -f n8n
```

## Using Puppeteer in n8n Workflows

### Basic Usage Template
In any n8n Code node, use this structure:

```javascript
const puppeteer = require('/home/node/custom_modules/node_modules/puppeteer');

const browser = await puppeteer.launch({
    headless: true,
    executablePath: '/usr/bin/chromium-browser',
    args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--single-process'
    ]
});

try {
    const page = await browser.newPage();
    
    // Your scraping logic here
    await page.goto('https://example.com', { waitUntil: 'networkidle2' });
    
    // Extract data
    const data = await page.evaluate(() => {
        return document.title;
    });
    
    await browser.close();
    
    return [{ json: { data } }];
    
} catch (error) {
    await browser.close();
    throw error;
}
```

### Advanced Usage with Stealth
For sites with anti-bot detection:

```javascript
const puppeteer = require('/home/node/custom_modules/node_modules/puppeteer-extra');
const StealthPlugin = require('/home/node/custom_modules/node_modules/puppeteer-extra-plugin-stealth');

puppeteer.use(StealthPlugin());

const browser = await puppeteer.launch({
    headless: true,
    executablePath: '/usr/bin/chromium-browser',
    args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-blink-features=AutomationControlled'
    ]
});

const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080 });
await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36');
```

## Troubleshooting

### Common Issues and Solutions

1. **Encryption key mismatch error**
   ```bash
   sudo docker compose down
   sudo docker volume rm n8n_data
   sudo docker volume create n8n_data
   sudo docker compose up -d
   ```

2. **Chromium not found**
   ```bash
   # Verify Chromium is installed in container
   sudo docker exec n8n-docker-caddy-n8n-1 chromium-browser --version
   ```

3. **Puppeteer module not found**
   ```bash
   # Check module installation
   sudo docker exec n8n-docker-caddy-n8n-1 ls -la /home/node/custom_modules/node_modules/
   ```

4. **Container keeps restarting**
   ```bash
   # Check logs for specific errors
   sudo docker compose logs n8n | tail -50
   ```

## Maintenance

### Updating n8n Version
When n8n releases updates:

```bash
# Pull latest n8n base image
sudo docker pull n8nio/n8n:latest

# Rebuild custom image
sudo docker build -t n8n-puppeteer:latest .

# Restart services
sudo docker compose down
sudo docker compose up -d
```

### Updating Puppeteer Version
Edit the Dockerfile to change Puppeteer version:
```dockerfile
RUN npm init -y && \
    npm install puppeteer@NEW_VERSION puppeteer-core@NEW_VERSION
```

Then rebuild the image.

## Performance Considerations

- Each Puppeteer instance uses ~512MB RAM
- Chromium startup takes 2-3 seconds
- For parallel scraping, limit concurrent browsers to avoid memory issues
- Close browsers properly to prevent memory leaks

## Security Notes

- Always use `--no-sandbox` in Docker containers
- The custom modules are installed in `/home/node/custom_modules` to avoid conflicts
- Puppeteer runs as the `node` user, not root
- Chromium runs in headless mode by default

## Tested Configuration
- **Base Image**: n8nio/n8n:latest
- **Puppeteer**: 21.0.0
- **Chromium**: Alpine Linux package (latest)
- **Node.js**: Included in n8n base image
- **PostgreSQL**: 15
- **Last Updated**: September 2025

## Quick Test Code
Paste this in an n8n Code node to verify setup:

```javascript
const puppeteer = require('/home/node/custom_modules/node_modules/puppeteer');

const browser = await puppeteer.launch({
    headless: true,
    executablePath: '/usr/bin/chromium-browser',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
});

const page = await browser.newPage();
await page.goto('https://example.com');

const title = await page.title();
const h1Text = await page.$eval('h1', el => el.textContent);

await browser.close();

return [{
    json: {
        success: true,
        title: title,
        h1: h1Text,
        message: 'Puppeteer is working correctly!',
        timestamp: new Date().toISOString()
    }
}];
```

Expected output:
```json
{
  "success": true,
  "title": "Example Domain",
  "h1": "Example Domain",
  "message": "Puppeteer is working correctly!",
  "timestamp": "2025-09-17T21:08:33.206Z"
}
```
```
