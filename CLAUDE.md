# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Mule 4 application that acts as a **custom reporter endpoint for Anypoint API Functional Monitoring (AFM)**. AFM/BAT monitors POST their execution results to `POST /load`; the app stores the raw result in MongoDB and a flattened, per-endpoint row in MySQL, enriched with API name/version looked up from Anypoint Platform.

## Build & run

Standard Mule Maven project (`packaging: mule-application`) targeting **Mule 4.9 LTS on Java 17**, deployed to **CloudHub 1.0** (not CloudHub 2.0). See `README.md` for setup and deployment steps. There are no MUnit tests.

```bash
JAVA_HOME=/opt/homebrew/opt/openjdk@17 mvn clean package   # build the deployable jar into target/
```

The build must run on JDK 17. The MongoDB connector rejects newer JDKs (e.g. 25) at `process-classes`.

### Secrets

No credentials are kept in the repo.
- `config.yaml` holds only non-secret settings. The secure properties are listed under `secureProperties` in `mule-artifact.json`: `mongodb.user`, `mongodb.password`, `mysqldb.user`, `mysqldb.password`, `anypoint.platform.auth.client_id`, and `anypoint.platform.auth.client_secret`. Supply them at deploy time as CloudHub 1.0 application properties. Runtime Manager masks them because they are listed in `secureProperties`. The CH1 CLI has no separate secure flag, so `--property` is used for them too. When running locally, pass them as `-M-D<name>=<value>` runtime args. Never add values for them to `config.yaml`.
- If you add a new secret, add it to `secureProperties` in `mule-artifact.json` as well.
- BAT scripts read API credentials with `secret('<alias>') default '...'`, which resolves through Anypoint Secrets Manager. The `bat grant` command adds the alias mapping to `bat.yaml`. This only works for monitors run from a private location.
- The example payloads and `application-types.xml` contain captured request headers. Keep their credential values redacted.
- The repo is public. Org/env IDs, database hosts, and app/API URLs are `YOUR_...` placeholders (or `example.com` in the sample payloads). Real values are supplied as deploy-time properties, which override `config.yaml`. Don't commit real values.

Local smoke test (once the app is running):

```bash
curl -X POST localhost:8081/load -H 'Content-Type: application/json' \
  -d @src/main/resources/examples/afm-test-history-execution-single-endpoint-example.json
```

The MongoDB and MySQL JDBC drivers are declared as `sharedLibraries` in the mule-maven-plugin config. If you add a driver dependency, register it there too. The Mongo driver version (`mongodb-driver-legacy`) should match the version the MongoDB connector was built against.

## Architecture

- `src/main/mule/global.xml` holds all global configs: HTTP listener, MongoDB, MySQL (`Database_Config`), and the Anypoint Platform HTTP request config. Values come from `src/main/resources/config.yaml`.
- `src/main/mule/import.xml` holds the logic:
  - `load-monitoring-historyFlow` (`/load`): saves the payload to `vars.afmTestHistory` and immediately returns `"Payload received."`. All the processing below happens inside an `<async>` scope, so errors never reach the AFM caller.
    1. If `mongodb.enabled` is `"true"` (default `"false"`), inserts the full raw document into the Mongo collection `mongodb.collection`. The insert sits inside a `try` with `on-error-continue`, so a MongoDB failure is logged and never blocks the MySQL inserts. MySQL is the required store; MongoDB is an optional raw archive. `mongodb.user` and `mongodb.password` default to `""` in `config.yaml` so the app starts with MongoDB disabled.
    2. Builds a header from the suite-level `name` and `metadata.*` fields.
    3. Runs a nested `foreach`: `result[]` (each `it should` test), then `result[].result[]` (each HTTP call). Each HTTP call becomes one flattened record.
    4. Gets the API instance ID from the request header `result.options.headers.'X-Api-Instance-Id'`. BAT title-cases header names, so the BAT script must send an `x-api-instance-id` header on every request.
    5. Calls the `GetAPINameAndId` sub-flow, which runs three Platform calls for each endpoint: a client-credentials token, the API Manager API details (`assetId`, `productVersion`), and the Exchange asset details (`name`).
    6. Inserts the record into the MySQL table `afm_test_history`. `startDate` arrives as epoch seconds (older BAT, and the sample payloads) or as an ISO-8601 string (real BAT 3.x runs). The flatten step normalizes it to epoch seconds for `FROM_UNIXTIME`.
- The MySQL schema is in `src/test/resources/ddl.sql`. If you add a field, update the DDL, the flatten/append DataWeave, and the `INSERT` column list together.
- `src/main/resources/examples/` has sample AFM payloads for a single endpoint and for multiple endpoints. Use them as the reference for the incoming JSON shape.

## BAT monitor scripts

`src/test/resources/api-health-check-monitor/` and `src/test/resources/scripts/api-health-check-monitor/` are two variants of the same AFM test suite (`bat.yaml`, `main.dwl`, `exchange.json`). They point at different orgs, deployments, and reporter URLs. They are not run by Maven. They are published and scheduled through the BAT CLI / API Functional Monitoring. `bat.yaml` configures a `Custom` reporter whose `URL` must point at this app's deployed `/load` endpoint.
