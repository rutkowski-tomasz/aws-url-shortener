process.env.environment = "dev";

const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");
const { mockClient } = require("aws-sdk-client-mock");
const { handler } = require("../src/index");

const snsMock = mockClient(SNSClient);

beforeEach(() => {
    snsMock.reset();
});

describe('Lambda Function Tests', () => {
    const sampleDynamoDBEvent = {
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

    test('successfully publishes to SNS when processing INSERT event', async () => {
        // Setup SNS mock to simulate a successful publish
        snsMock.on(PublishCommand).resolves({
            MessageId: "12345"
        });

        const response = await handler(sampleDynamoDBEvent);

        const responseBody = JSON.parse(response.body);
        expect(response.statusCode).toEqual(200);
        expect(responseBody.isSuccess).toBeTruthy();
        expect(snsMock.calls(PublishCommand)).toHaveLength(1);
        expect(snsMock.calls(PublishCommand)[0].args[0].input).toMatchObject({
            TopicArn: expect.stringContaining("us-dev-url-created"),
            Message: expect.stringContaining('https://example.com')
        });
    });

    test('handles errors during message publication to SNS', async () => {
        // Simulate an error in publishing to SNS
        snsMock.on(PublishCommand).rejects(new Error("Network failure"));

        const response = await handler(sampleDynamoDBEvent);

        const responseBody = JSON.parse(response.body);
        expect(response.statusCode).toEqual(400);
        expect(responseBody.isSuccess).toBeFalsy();
        expect(responseBody.error).toContain("Network failure");
        expect(snsMock.calls(PublishCommand)).toHaveLength(1);
    });
});
