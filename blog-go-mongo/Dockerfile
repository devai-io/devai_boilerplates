# Build
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN go mod tidy && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /bin/blog .

# Run
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /bin/blog /bin/blog
EXPOSE 8080
ENTRYPOINT ["/bin/blog"]
