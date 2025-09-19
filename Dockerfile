# Use official Node.js LTS image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Install dependencies separately (better caching)
COPY package*.json ./
RUN npm install 

# Copy the rest of the backend source code
COPY . .

# Expose internal port (must match NODE_INTERNAL_PORT in .env)
EXPOSE ${NODE_INTERNAL_PORT}

# Start the server
CMD ["node", "index.js"]
