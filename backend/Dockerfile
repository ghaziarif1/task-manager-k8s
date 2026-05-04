# Backend Dockerfile multi-stage optimisé
FROM node:20-alpine AS builder
WORKDIR /usr/src/app
COPY package.json ./
RUN npm install
COPY . .

FROM node:20-alpine AS runner
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/src ./src
COPY --from=builder /usr/src/app/package.json ./package.json
ENV NODE_ENV=production
EXPOSE 4000
CMD ["node", "src/index.js"]
