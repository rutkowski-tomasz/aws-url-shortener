import { DynamoDBClient, UpdateItemCommand } from "@aws-sdk/client-dynamodb";
import { S3Client, DeleteObjectsCommand } from "@aws-sdk/client-s3";
import { mockClient } from "aws-sdk-client-mock";
import { beforeEach, describe, test, expect, beforeAll, afterAll } from '@jest/globals';
import { SQSEvent, Callback, Context } from "aws-lambda";

const dynamoDbClientMock = mockClient(DynamoDBClient);
const s3ClientMock = mockClient(S3Client);

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
                    detail: {
                    code: 'abcd1234'
                    }
                })
            }
        ]
    } as any);

    test('successfully archives item in DynamoDB', async () => {
        dynamoDbClientMock.on(UpdateItemCommand).resolves({
            "$metadata": {
                "httpStatusCode": 200,
                "requestId": "U3BNLREPLJ3J66QD6PQ031241NVV4KQNSO5AEMVJF66Q9ASUAAJG",
                "attempts": 1,
                "totalRetryDelay": 0
            }
        });
        s3ClientMock.on(DeleteObjectsCommand).resolves({});

        await handler(getSampleDynamoDBEvent(), {} as Context, {} as Callback);

        expect(dynamoDbClientMock.commandCalls(UpdateItemCommand)).toHaveLength(1);
        expect(dynamoDbClientMock.commandCalls(UpdateItemCommand)[0].args[0].input).toMatchObject({
            TableName: 'us-dev-shortened-urls',
            Key: {
                code: { S: 'abcd1234' }
            }
        });
    });

    test('fails given error during DynamoDB update', async () => {
        dynamoDbClientMock.on(UpdateItemCommand).rejects(new Error("Network failure"));

        const action = handler(getSampleDynamoDBEvent(), {} as Context, {} as Callback);

        await expect(action).rejects.toThrow("Network failure");
    });
});

describe('Integration Test', () => {
    beforeAll(() => {
        dynamoDbClientMock.restore();
        s3ClientMock.restore();
    });

    afterAll(() => {
        mockClient(DynamoDBClient);
        mockClient(S3Client);
    });

    test('integration test', async () => {
        const event: SQSEvent = {
            Records: [
                {
                    body: JSON.stringify({
                        detail: {
                            code: 'abcd1234',
                            userId: '123456789012'
                        }
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
