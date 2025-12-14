# Stage 1: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: runtime
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
# Expose port 8080 au lieu de 80
EXPOSE 8080
# Modifier le port dans nginx
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf
CMD ["nginx", "-g", "daemon off;"]
