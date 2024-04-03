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
