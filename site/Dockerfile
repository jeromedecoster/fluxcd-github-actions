FROM node:14.9-slim AS build
WORKDIR /app
ADD package.json .
RUN npm install

FROM node:14.9-slim
ENV NODE_ENV production
ENV WEBSITE_PORT 3000
WORKDIR /app
COPY --from=build /app .
ADD . .
EXPOSE 3000
CMD ["node", "server.js"]
