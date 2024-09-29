import { DynamoDBClient, DeleteItemCommand } from "@aws-sdk/client-dynamodb";
import { mockClient } from "aws-sdk-client-mock";
import { beforeEach, describe, test, expect, beforeAll, afterAll } from '@jest/globals';
import { SQSEvent, Callback, Context } from "aws-lambda";

const dynamoDbClientMock = mockClient(DynamoDBClient);

process.env.ENVIRONMENT = "dev";
import { handler } from "./index";

beforeEach(() => {
    dynamoDbClientMock.reset();
});

describe('Unit Tests', () => {
    const getSampleDynamoDBEvent = (): SQSEvent => ({
        Records: [
            {
                body: JSON.stringify({
                    code: 'abcd1234'
                })
            }
        ]
    } as any);

    test('successfully deletes item from DynamoDB', async () => {
        dynamoDbClientMock.on(DeleteItemCommand).resolves({});

        await handler(getSampleDynamoDBEvent(), {} as Context, {} as Callback);

        expect(dynamoDbClientMock.commandCalls(DeleteItemCommand)).toHaveLength(1);
        expect(dynamoDbClientMock.commandCalls(DeleteItemCommand)[0].args[0].input).toMatchObject({
            TableName: 'us-dev-shortened-urls',
            Key: {
                code: { S: 'abcd1234' }
            }
        });
    });

    test('fails given error during DynamoDB delete', async () => {
        dynamoDbClientMock.on(DeleteItemCommand).rejects(new Error("Network failure"));

        const action = handler(getSampleDynamoDBEvent(), {} as Context, {} as Callback);

        await expect(action).rejects.toThrow("Network failure");
    });
});

describe('Integration Test', () => {
    beforeAll(() => {
        dynamoDbClientMock.restore();
    });

    afterAll(() => {
        mockClient(DynamoDBClient);
    });

    test('integration test', async () => {
        const event: SQSEvent = {
            Records: [
                {
                    body: JSON.stringify({
                        code: 'abcd1234'
                    }),
                    messageId: '123',
                    receiptHandle: '456',
                    attributes: {
                        ApproximateReceiveCount: '1',
                        SentTimestamp: '1234567890',
                        SenderId: '123456789012',
                        ApproximateFirstReceiveTimestamp: '1234567890'
                    },
                    messageAttributes: {},
                    eventSource: 'aws:sqs',
                    eventSourceARN: 'arn:aws:sqs:us-east-1:123456789012:MyQueue',
                    awsRegion: 'us-east-1',
                    md5OfBody: '789012345678901234567890',
                }
            ]
        };

        await handler(event, {} as Context, {} as Callback);
    });
});
