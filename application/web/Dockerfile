FROM node:16.17.1-alpine AS web
# 使用阿里云镜像源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
WORKDIR /app
COPY package*.json ./
RUN npm config set registry https://registry.npmmirror.com && npm install
COPY . .
RUN npm run build

FROM nginx:stable-alpine3.20
# 使用阿里云镜像源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --no-cache tzdata
COPY --from=web /app/dist /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
