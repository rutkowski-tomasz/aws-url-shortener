import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";
import { mockClient } from "aws-sdk-client-mock";
import { beforeEach, describe, test, expect, beforeAll, afterAll } from '@jest/globals';
import { DynamoDBStreamEvent, Callback, Context } from "aws-lambda";

const snsMock = mockClient(SNSClient);

process.env.ENVIRONMENT = "dev";

import { handler } from "./index";

import { handler } from "./index";

beforeEach(() => {
    snsMock.reset();
});

describe('Unit Tests', () => {
    const getSampleDynamoDBEvent = (): DynamoDBStreamEvent => ({
        Records: [
            {
                eventName: 'INSERT',
                dynamodb: {
                    NewImage: {
                        code: { S: 'abcd1234' },
                        longUrl: { S: 'https://example.com' },
                        userId: { S: 'user-001' },
                        createdAt: { N: '1234567890' }
                    }
                }
            }
        ]
    });

    test('successfully publishes to SNS when processing INSERT event', async () => {
        snsMock.on(PublishCommand).resolves({
            MessageId: "12345"
        });

        await handler(getSampleDynamoDBEvent(), {} as Context, {} as Callback);

        expect(snsMock.commandCalls(PublishCommand)).toHaveLength(1);
        expect(snsMock.commandCalls(PublishCommand)[0].args[0].input).toMatchObject({
            TopicArn: expect.stringContaining("us-dev-url-created"),
            Message: JSON.stringify({
                code: 'abcd1234',
                longUrl: 'https://example.com',
                userId: 'user-001',
                createdAt: 1234567890
            })
        });
    });

    test('handles errors during message publication to SNS', async () => {
        snsMock.on(PublishCommand).rejects(new Error("Network failure"));

        const action = handler(getSampleDynamoDBEvent(), {} as Context, {} as Callback);

        await expect(action).rejects.toThrow("Network failure");
    });

    test('handles errors during message publication to SNS', async () => {

        const event = getSampleDynamoDBEvent();
        event.Records[0].eventName = 'REMOVE';

        await handler(event, {} as Context, {} as Callback);

        expect(snsMock.commandCalls(PublishCommand)).toHaveLength(0);
    });
});

describe('Integration Test', () => {
    beforeAll(() => {
        snsMock.restore();
    });

    afterAll(() => {
        mockClient(SNSClient);
    });

    test('integration test', async () => {
        const event: DynamoDBStreamEvent = {
            Records: [
                {
                    eventName: 'INSERT',
                    dynamodb: {
                        NewImage: {
                            code: { S: 'abcd1234' },
                            longUrl: { S: 'https://example.com' },
                            userId: { S: 'user-001' },
                            createdAt: { N: '1234567890' }
                        }
                    }
                }
            ]
        };

        await handler(event, {} as Context, {} as Callback);
    });
});
