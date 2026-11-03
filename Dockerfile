# ETAPA 1: Compilación
FROM ghcr.io/cirruslabs/flutter:stable AS build-env
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release --no-tree-shake-icons

# ETAPA 2: Servir con Nginx
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
