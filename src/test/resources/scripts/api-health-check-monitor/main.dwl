import * from bat::BDD
import * from bat::Assertions

var clientId = secret('clientId-alias') default 'Client Not Found'
var clientSecret = secret('clientSecret-alias') default 'Secret Not Found'
---
suite("API Health Check") in [
  it should "Assert endpoint: " in [
    GET `https://YOUR_API_HOST_1/hellomule` with {
      "headers": {
        "x-api-instance-id": "YOUR_API_INSTANCE_ID_1"
      }
    } assert [
        $.response.status mustEqual 200
    ]
  ],
  it should "Assert endpoint: " in [
    GET `https://YOUR_API_HOST_2/api/ping` with {
      "headers": {
        "client_id": clientId,
        "client_secret": clientSecret,
        "x-api-instance-id": "YOUR_API_INSTANCE_ID_2"
      }
    } assert [
        $.response.status mustEqual 200
    ]
  ]
]