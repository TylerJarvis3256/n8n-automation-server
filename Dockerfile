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
