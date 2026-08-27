FROM golang:1.23-alpine AS build
WORKDIR /src
ENV GIN_MODE=release
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o /bin/server ./cmd/server

FROM alpine:3.19
COPY --from=build /bin/server /bin/server
EXPOSE 8080
ENTRYPOINT ["/bin/server"]
