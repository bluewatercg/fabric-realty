# 使用指定版本号确保构建一致性
FROM golang:1.23.4-alpine AS builder
ENV GOPROXY https://goproxy.cn,direct
WORKDIR /app
COPY . .
RUN go mod vendor
# 使用 vendor 模式，避免构建时下载依赖导致网络问题
RUN CGO_ENABLED=0 go build -mod=vendor -o main

FROM alpine:3.21
# 使用阿里云镜像源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk add --no-cache tzdata
WORKDIR /app
COPY --from=builder /app/main .
COPY --from=builder /app/config/config-docker.yaml /app/config/config.yaml
CMD ["./main"]
