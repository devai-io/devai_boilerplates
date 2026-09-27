FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /bin/blog .

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /bin/blog /bin/blog
EXPOSE 8080
ENTRYPOINT ["/bin/blog"]
