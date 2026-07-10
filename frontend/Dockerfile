# Production image — Next.js 16, multi-stage.
# NEXT_PUBLIC_API_URL is baked into the client bundle at build time:
#   docker build --build-arg NEXT_PUBLIC_API_URL=https://payforge-api.example.com .
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
ARG NEXT_PUBLIC_API_URL=http://localhost:3200
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL \
    NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1

COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/next.config.ts ./

RUN addgroup -S app -g 1001 && adduser -S app -u 1001 && chown -R app:app /app
USER app

EXPOSE 3000
CMD ["npm", "run", "start"]
