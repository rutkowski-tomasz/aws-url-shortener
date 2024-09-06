const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { mockClient } = require("aws-sdk-client-mock");
const { handler } = require("../src/index");

process.env.environment = "dev";

const ddbMock = mockClient(DynamoDBDocumentClient);

const sampleEvent = {
  "resource": "/shorten-url",
  "path": "/shorten-url",
  "httpMethod": "POST",
  "headers": null,
  "multiValueHeaders": null,
  "queryStringParameters": null,
  "multiValueQueryStringParameters": null,
  "pathParameters": null,
  "stageVariables": null,
  "requestContext": {
      "resourceId": "nq5ycs",
      "authorizer": {
          "claims": {
              "sub": "77766666-f0a1-7003-c2b9-b33fe4125f0d",
              "email_verified": "true",
              "iss": "https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_mxbE0ja3h",
              "cognito:username": "myEmail@gmail.com",
              "origin_jti": "b2b287c3-c5e0-4d7a-b3b4-ba749c80c8b5",
              "aud": "4np6oaiu11oom6khgturukdfus",
              "event_id": "b7cd4971-b683-4d48-aed9-27fb5ca1afce",
              "token_use": "id",
              "auth_time": "1714565422",
              "exp": "Wed May 01 13:10:22 UTC 2024",
              "iat": "Wed May 01 12:10:22 UTC 2024",
              "jti": "12a93356-c2bd-4551-b09e-dc7a137378fe",
              "email": "myEmail@gmail.com"
          }
      },
      "resourcePath": "/shorten-url",
      "httpMethod": "POST",
      "extendedRequestId": "Vsi9cHCGliAFS4w=",
      "requestTime": "04/Apr/2024:10:19:40 +0000",
      "path": "/shorten-url",
      "accountId": "024853653660",
      "protocol": "HTTP/1.1",
      "stage": "test-invoke-stage",
      "domainPrefix": "testPrefix",
      "requestTimeEpoch": 1712225980198,
      "requestId": "7e7aa406-c78d-4050-b766-0fc2c1bde2dc",
      "identity": {
          "cognitoIdentityPoolId": null,
          "cognitoIdentityId": null,
          "apiKey": "test-invoke-api-key",
          "principalOrgId": null,
          "cognitoAuthenticationType": null,
          "userArn": "arn:aws:iam::024853653660:user/tomek",
          "apiKeyId": "test-invoke-api-key-id",
          "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
          "accountId": "024853653660",
          "caller": "AIDAQLSLEVCOHVVBSEET4",
          "sourceIp": "test-invoke-source-ip",
          "accessKey": "ASIAQLSLEVCOPEWQXDCX",
          "cognitoAuthenticationProvider": null,
          "user": "AIDAQLSLEVCOHVVBSEET4"
      },
      "domainName": "testPrefix.testDomainName",
      "apiId": "5fx9tfed9e"
  },
  "body": "{\n    \"longUrl\": \"https://example.com/\"\n}",
  "isBase64Encoded": false
};

beforeEach(() => {
  ddbMock.reset();
});

test('successfully inserts item into DynamoDB and returns shortened URL', async () => {
  ddbMock.on(PutCommand).resolves({
    "$metadata": {
        "httpStatusCode": 200,
        "requestId": "3F09SM5ICH2406M324ANIMJJHRVV4KQNSO5AEMVJF66Q9ASUAAJG",
        "attempts": 1,
        "totalRetryDelay": 0
    }
  });

  const response = await handler(sampleEvent);

  const responseBody = JSON.parse(response.body);
  expect(response.statusCode).toEqual(200);
  expect(responseBody.isSuccess).toBeTruthy();
  expect(responseBody.result).toHaveProperty('code');
  expect(responseBody.result.longUrl).toEqual('https://example.com/');
  expect(ddbMock.calls(PutCommand)).toHaveLength(1);
  const putCommandCall = ddbMock.calls(PutCommand)[0].args[0];
  expect(putCommandCall.input.TableName).toEqual(`us-${process.env.environment}-shortened-urls`);
  expect(putCommandCall.input.Item).toHaveProperty('code');
  expect(putCommandCall.input.Item.longUrl).toEqual('https://example.com/');
});
