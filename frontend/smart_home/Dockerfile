FROM node:lts-alpine3.24

RUN npm install -g serve

WORKDIR /app

COPY web .

EXPOSE 8080

CMD ["serve", "-s", ".", "-l", "8080"]
