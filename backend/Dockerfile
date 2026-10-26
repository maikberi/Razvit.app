# Собираем TypeScript в отдельном слое, чтобы в финальном образе не было
# devDependencies и исходников — только скомпилированный JS и то, что
# нужно для запуска (миграции — обычные .sql файлы, читаются в рантайме).
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install --include=dev
COPY . .
RUN npm run build

FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm install --omit=dev
COPY --from=build /app/dist ./dist
COPY db ./db

EXPOSE 3000
CMD ["sh", "-c", "node dist/db/migrate.js && node dist/server.js"]
