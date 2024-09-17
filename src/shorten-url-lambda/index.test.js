const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { mockClient } = require("aws-sdk-client-mock");
const { handler } = require("./index");

process.env.ENVIRONMENT = "dev";

const ddbMock = mockClient(DynamoDBDocumentClient);

const sampleEvent = {
  "resource": "/shorten-url",
  "path": "/shorten-url",
  "httpMethod": "POST",
  "requestContext": {
    "authorizer": {
      "claims": {
        "sub": "77766666-f0a1-7003-c2b9-b33fe4125f0d",
        "email": "myEmail@gmail.com"
      }
    }
  },
  "body": "{\n    \"longUrl\": \"https://example.com/\"\n}",
  "isBase64Encoded": false
};

describe('Unit Tests', () => {
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

  test('handles DynamoDB insertion error', async () => {
    ddbMock.on(PutCommand).rejects(new Error('DynamoDB insertion failed'));

    const response = await handler(sampleEvent);

    expect(response.statusCode).toEqual(400);
    const responseBody = JSON.parse(response.body);
    expect(responseBody.isSuccess).toBeFalsy();
    expect(responseBody.error).toContain('DynamoDB insertion failed');
  });
});

describe('Integration Test', () => {
  beforeAll(() => {
    ddbMock.restore();
  });

  afterAll(() => {
    mockClient(DynamoDBDocumentClient);
  });

  test('integration test', async () => {
    const result = await handler(sampleEvent);
    console.log('Integration test result:', result);

    expect(result.statusCode).toBe(200);

    const body = JSON.parse(result.body);
    expect(body.isSuccess).toBe(true);
    expect(body.result).toHaveProperty('code');
    expect(body.result).toHaveProperty('longUrl');
    expect(body.result).toHaveProperty('userId');
    expect(body.result).toHaveProperty('createdAt');

    console.log('Shortened URL result:', body.result);
  });
});
