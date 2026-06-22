# Multi-stage build -> small static binary on a distroless base.
# This is already a "best case" container (no shell, ~static), so the
# size/footprint comparison against Wasm is conservative and fair.
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server main.go

FROM gcr.io/distroless/static-debian12
COPY --from=build /server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
