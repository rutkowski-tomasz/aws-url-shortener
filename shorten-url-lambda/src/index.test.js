const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { mockClient } = require("aws-sdk-client-mock");
const { handler } = require("./index");

const ddbMock = mockClient(DynamoDBDocumentClient);

beforeEach(() => {
  ddbMock.reset();
});

test('successfully inserts item into DynamoDB and returns shortened URL', async () => {
  const event = { longUrl: "https://example.com" };

  ddbMock.on(PutCommand).resolves({
    "$metadata": {
        "httpStatusCode": 200,
        "requestId": "3F09SM5ICH2406M324ANIMJJHRVV4KQNSO5AEMVJF66Q9ASUAAJG",
        "attempts": 1,
        "totalRetryDelay": 0
    }
  });

  const response = await handler(event);

  const responseBody = JSON.parse(response.body);
  expect(response.statusCode).toEqual(200);
  expect(responseBody.isSuccess).toBeTruthy();
  expect(responseBody.result).toHaveProperty('code');
  expect(responseBody.result.longUrl).toEqual(event.longUrl);
  expect(ddbMock.calls(PutCommand)).toHaveLength(1);
  const putCommandCall = ddbMock.calls(PutCommand)[0].args[0];
  expect(putCommandCall.input.TableName).toEqual('ShortenedUrls');
  expect(putCommandCall.input.Item).toHaveProperty('code');
  expect(putCommandCall.input.Item.longUrl).toEqual(event.longUrl);
});
