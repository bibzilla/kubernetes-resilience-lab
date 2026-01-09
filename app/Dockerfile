# Node.js 20 on a small Alpine Linux base
FROM node:20-alpine

# Application directory
WORKDIR /app

# Copy dependency manifest first to leverage Docker layer caching
COPY package.json ./

# Install production dependencies
RUN npm install --omit=dev

# Copy application source
COPY server.js ./

# Application listens on port 8080
EXPOSE 8080

# Default container startup command
CMD ["node", "server.js"]
