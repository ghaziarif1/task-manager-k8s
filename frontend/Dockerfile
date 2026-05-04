FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# Copier les fichiers de d�pendances
COPY package.json package-lock.json ./

# Installer TOUTES les d�pendances (production + dev)
RUN npm ci

# Copier le reste du code source
COPY . .


# Construire l'application
RUN npm run build

# Stage de production avec Nginx
FROM nginx:stable-alpine AS production

# Copier le build dans le dossier Nginx
COPY --from=builder /usr/src/app/dist /usr/share/nginx/html

# Copier la configuration Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exposer le port 80
EXPOSE 80

# D�marrer Nginx
CMD ["nginx", "-g", "daemon off;"]
