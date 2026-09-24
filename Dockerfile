FROM rust:1.98-alpine@sha256:7cc1c22d77d9432f7fe012a70e6d3e555af54c2a6832700ed7d553f1769ae89f AS rust_base

RUN apk add musl-dev pkgconfig wget

# find rust licenses
FROM rust_base AS rust_licenses

RUN cargo install cargo-bundle-licenses

RUN mkdir /app
COPY /server app/
WORKDIR /app

RUN cargo bundle-licenses --format json --output /app/server-licenses.json

# build frontend
FROM node:22-alpine@sha256:41e4389f3d988d2ed55392df4db1420ad048ae53324a8e2b7c6d19508288107e AS ui_builder

RUN mkdir /app
COPY /ui app/
COPY --from=rust_licenses /app/server-licenses.json /app/static/licenses/server-licenses.json

WORKDIR /app

RUN npm install
#  first generate licenses
RUN GENERATE_LICENSES=true npm run build
#  then build again, including licenses
RUN npm run build

# build server
FROM rust_base AS server_builder

RUN mkdir /app
COPY /server app/
WORKDIR /app

RUN cargo build --release

# assemble final image
FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

RUN apk add vips-tools

RUN mkdir /app
RUN mkdir /app/static
RUN mkdir /app/server
RUN mkdir /mise-data

COPY --from=ui_builder /app/build /app/static
COPY --from=server_builder /app/target/release/server /app/server/server

ENV MISE_STATIC_BUILD="/app/static"

CMD ["/app/server/server"]
