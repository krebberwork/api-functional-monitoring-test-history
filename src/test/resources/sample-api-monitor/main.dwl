import * from bat::BDD
import * from bat::Assertions

// Replace with the API under test. apiInstanceId is the API Manager instance ID;
// the reporter app uses it to look up the API name and version.
var apiHost = "https://YOUR_API_HOST"
var apiInstanceId = "YOUR_API_INSTANCE_ID"

// If the API enforces client ID, uncomment these and the client_id/client_secret
// headers below. Values come from Anypoint Secrets Manager (see README); this only
// works for monitors that run from a private location.
// var clientId = secret('clientId-alias') default 'Client Not Found'
// var clientSecret = secret('clientSecret-alias') default 'Secret Not Found'
---
suite("YOUR_SUITE_NAME") in [
  // One `it should` block per endpoint. Call read-only endpoints only:
  // the monitor runs on a schedule, so a POST would create data on every run.
  it should "Assert endpoint: " in [
    GET `$(apiHost)/YOUR_RESOURCE_PATH` with {
      "headers": {
        // "client_id": clientId,
        // "client_secret": clientSecret,
        "x-api-instance-id": apiInstanceId
      }
    } assert [
        $.response.status mustEqual 200
    ]
  ],
  it should "Assert endpoint: " in [
    GET `$(apiHost)/YOUR_OTHER_RESOURCE_PATH` with {
      "headers": {
        "x-api-instance-id": apiInstanceId
      }
    } assert [
        $.response.status mustEqual 200
    ]
  ]
]
