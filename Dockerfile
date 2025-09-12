FROM node:18-alpine

# Create app directory
WORKDIR /app

# Copy package files first (for better caching)
COPY package*.json ./


# Optional ENV (better keep in docker-compose/.env)
# ENV MYSQL_ROOT_PASSWORD=RxGuardian@123


# Install dependencies inside the container
RUN npm install

# Copy app source code
COPY . .

# Run your app
CMD ["node", "index.js"]


# to build:docker build -t rx_guardian_backend_image .