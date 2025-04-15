FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

ENV PORT=3000
ENV LOGSTASH_HOST=logstash
ENV LOGSTASH_PORT=5000

EXPOSE 3000

CMD ["node", "app.js"]