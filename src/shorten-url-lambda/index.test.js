const { PutCommand } = require("@aws-sdk/lib-dynamodb");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { SchedulerClient, CreateScheduleCommand } = require("@aws-sdk/client-scheduler");
const { mockClient } = require("aws-sdk-client-mock");
const { beforeEach, describe, test, expect, beforeAll, afterAll } = require('@jest/globals');

const ddbMock = mockClient(DynamoDBClient);
const schedulerMock = mockClient(SchedulerClient);

const sampleEvent = {
  "resource": "/shorten-url",
  "path": "/shorten-url",
  "httpMethod": "POST",
  "requestContext": {
    "authorizer": {
      "claims": {
        "sub": "c0911170-0000-0000-0000-000000000000",
        "email": "myEmail@gmail.com"
      }
    }
  },
  "body": "{\n    \"longUrl\": \"https://example.com/\"\n}",
  "isBase64Encoded": false
};

process.env.ENVIRONMENT = "dev";
process.env.EVENT_BUS_ARN = "arn:aws:events:eu-central-1:024853653660:event-bus/us-dev-url-shortener";
process.env.SCHEDULER_ROLE_ARN = "arn:aws:iam::024853653660:role/us-dev-scheduler-role";
const { handler } = require("./index");

describe('Unit Tests', () => {
  beforeEach(() => {
    ddbMock.reset();
    schedulerMock.reset();
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

    schedulerMock.on(CreateScheduleCommand).resolves({});

    const response = await handler(sampleEvent);

    const responseBody = JSON.parse(response.body);
    expect(response.statusCode).toEqual(200);
    expect(responseBody).toHaveProperty('code');

    expect(ddbMock.calls(PutCommand)).toHaveLength(1);
    const putCommandCall = ddbMock.calls(PutCommand)[0].args[0];
    expect(putCommandCall.input.TableName).toEqual(`us-${process.env.ENVIRONMENT}-shortened-urls`);
    expect(putCommandCall.input.Item).toHaveProperty('code');
    expect(putCommandCall.input.Item.longUrl).toEqual('https://example.com/');

    expect(schedulerMock.calls(CreateScheduleCommand)).toHaveLength(1);
    const createScheduleCommandCall = schedulerMock.calls(CreateScheduleCommand)[0].args[0];
    expect(createScheduleCommandCall.input.Name).toMatch(/^us-dev-delete-shortened-url-/);
    expect(createScheduleCommandCall.input.ScheduleExpression).toMatch(/^at\(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\)$/);
    expect(createScheduleCommandCall.input.Target.Arn).toEqual(process.env.EVENT_BUS_ARN);
    expect(createScheduleCommandCall.input.Target.RoleArn).toEqual(process.env.SCHEDULER_ROLE_ARN);
    expect(createScheduleCommandCall.input.FlexibleTimeWindow).toEqual({ Mode: "OFF" });
    expect(createScheduleCommandCall.input.EventBridgeParameters.DetailType).toEqual("DeleteShortenedUrl");
    expect(createScheduleCommandCall.input.EventBridgeParameters.Source).toEqual("url-shortener");
    expect(createScheduleCommandCall.input.ActionAfterCompletion).toEqual("DELETE");

    const payload = JSON.parse(createScheduleCommandCall.input.Target.Input);
    expect(payload).toHaveProperty('code');
    expect(payload).toHaveProperty('userId');
    expect(payload.userId).toEqual(sampleEvent.requestContext.authorizer.claims.sub);
  });

  test('handles DynamoDB insertion error', async () => {
    ddbMock.on(PutCommand).rejects(new Error('DynamoDB insertion failed'));
    const response = await handler(sampleEvent);
    expect(response.statusCode).toEqual(500);
  });
});

describe('Integration Test', () => {
  beforeAll(() => {
    ddbMock.restore();
    schedulerMock.restore();
  });

  afterAll(() => {
    mockClient(DynamoDBClient);
    mockClient(SchedulerClient);
  });

  test('integration test', async () => {
    const result = await handler(sampleEvent);
    console.log('Integration test result:', result);

    expect(result.statusCode).toBe(200);

    const body = JSON.parse(result.body);
    expect(body).toHaveProperty('code');

    console.log('Shortened URL result:', body.result);
  });
});
