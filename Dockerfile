FROM ubuntu:22.04

# Install Node.js, npm, nginx and required utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    nginx \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# The Node application lives under api/
COPY api/package*.json ./api/
RUN cd api && npm install --omit=dev

# Copy the application
COPY api/ ./api/

# Copy the rest of the project
COPY . .

# nginx config — proxies port 80 to app on 3000
RUN printf 'server {\n\
  listen 80;\n\
  location / {\n\
    proxy_pass http://127.0.0.1:3000;\n\
    proxy_set_header Host $host;\n\
  }\n\
  location /healthz {\n\
    proxy_pass http://127.0.0.1:3000/healthz;\n\
  }\n\
  location /readyz {\n\
    proxy_pass http://127.0.0.1:3000/readyz;\n\
  }\n\
}\n' > /etc/nginx/sites-available/default

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80 3000

ENTRYPOINT ["/docker-entrypoint.sh"]
