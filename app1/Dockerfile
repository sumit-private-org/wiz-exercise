# Building the binary of the App
FROM golang:1.19 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky


FROM alpine:3.17.0 as release
RUN apk add --no-cache bash
SHELL ["/bin/bash", "-c"]

WORKDIR /app
COPY --from=build  /go/src/tasky/tasky .
COPY --from=build  /go/src/tasky/assets ./assets
RUN echo "Wiz Exercise Demo" > wizexercise.txt
EXPOSE 8080
# Define environment variables (if needed, though connection string is better via K8s secrets)
# ENV MONGODB_URI="mongodb://user:pass@host:port/db"
# ENV SECRET_KEY="your_secret_key"
ENTRYPOINT ["/app/tasky"]
