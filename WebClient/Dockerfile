# Build stage
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY tsconfig.json vite.config.*.ts* vite.config.*.js* ./
COPY index.html ./
COPY src ./src
RUN npm run build

# Serve stage
FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
# minimal security headers example
COPY entrypoint.sh /entrypoint.sh
RUN printf '\nadd_header X-Content-Type-Options "nosniff";\nadd_header X-Frame-Options "DENY";\n' >> /etc/nginx/conf.d/default.conf
RUN chmod +x /entrypoint.sh
EXPOSE 80
HEALTHCHECK CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
CMD ["/entrypoint.sh"]
