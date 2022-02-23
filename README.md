# Local Containerized App connecting to CloudSQL Proxy Test Branch

This branch was made to test a containerized app locally that connects with an also containerized [CloudSQL Proxy](https://cloud.google.com/sql/docs/postgres/connect-admin-proxy#connecting-docker), according to https://github.com/GoogleCloudPlatform/functions-framework-dart/issues/302#issuecomment-1048325596. To do that:

1. [Create a Service Account](https://cloud.google.com/sql/docs/mysql/connect-admin-proxy#create-service-account), add a Key to it and download it. 
2. Copy or move the key file to a `credentials.json` file in this repository's root directory.
3. Substitute `<INSTANCE_CONNECTION_NAME>` at [`docker-compose.yml`](./docker-compose.yml) for your CloudSQL [instance connection name](https://cloud.google.com/sql/docs/postgres/connect-admin-proxy#docker).
4. Copy the [`.env.template`](./.env.template) file into `.env` file and replace the values of the environment values. In particular, the following variables should be `DB_HOST=cloudsql-proxy` and `USE_UNIX_SOCKET=true`.
5. Run `docker compose up web`.
