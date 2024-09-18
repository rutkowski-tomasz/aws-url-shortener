import { S3Event } from "aws-lambda";
import { mockClient } from "aws-sdk-client-mock";
import { DynamoDBDocumentClient, GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from "@aws-sdk/client-apigatewaymanagementapi";
import { handler } from './index';

const ddbMock = mockClient(DynamoDBDocumentClient);
const apiGatewayMock = mockClient(ApiGatewayManagementApiClient);

jest.mock('@aws-sdk/client-apigatewaymanagementapi');

describe('Unit Tests', () => {
    beforeEach(() => {
        ddbMock.reset();
        apiGatewayMock.reset();
        process.env.ENVIRONMENT = 'test';
        process.env.AWS_REGION = 'us-east-1';
        process.env.WS_API_GATEWAY_ID = 'testapi';
        jest.clearAllMocks();
    });

    const createMockSQSEvent = (s3Event: S3Event): any => ({
        Records: [
            {
                body: JSON.stringify({
                    Message: JSON.stringify(s3Event)
                })
            }
        ]
    });

    test('successfully processes S3 event and sends WebSocket message', async () => {
        const mockS3Event: S3Event = {
            Records: [
                {
                    s3: {
                        object: {
                            key: 'abc123/preview.jpg'
                        }
                    }
                }
            ]
        } as any;

        const mockSQSEvent = createMockSQSEvent(mockS3Event);

        ddbMock.on(GetCommand).resolves({
            Item: { userId: 'user123', code: 'abc123' }
        });

        ddbMock.on(QueryCommand).resolves({
            Items: [{ connectionId: 'conn123' }]
        });

        apiGatewayMock.on(PostToConnectionCommand).resolves({});

        await handler(mockSQSEvent);

        expect(ddbMock.commandCalls(GetCommand)).toHaveLength(1);
        expect(ddbMock.commandCalls(QueryCommand)).toHaveLength(1);
        expect(apiGatewayMock.commandCalls(PostToConnectionCommand)).toHaveLength(1);
    });

    test('handles missing shortened URL gracefully', async () => {
        const mockS3Event: S3Event = {
            Records: [
                {
                    s3: {
                        object: {
                            key: 'nonexistent/preview.jpg'
                        }
                    }
                }
            ]
        } as any;

        const mockSQSEvent = createMockSQSEvent(mockS3Event);

        ddbMock.on(GetCommand).resolves({});

        await handler(mockSQSEvent);

        expect(ddbMock.commandCalls(GetCommand)).toHaveLength(1);
        expect(ddbMock.commandCalls(QueryCommand)).toHaveLength(0);
        expect(apiGatewayMock.commandCalls(PostToConnectionCommand)).toHaveLength(0);
    });

    test('handles missing user connections gracefully', async () => {
        const mockS3Event: S3Event = {
            Records: [
                {
                    s3: {
                        object: {
                            key: 'abc123/preview.jpg'
                        }
                    }
                }
            ]
        } as any;

        const mockSQSEvent = createMockSQSEvent(mockS3Event);

        ddbMock.on(GetCommand).resolves({
            Item: { userId: 'user123', code: 'abc123' }
        });

        ddbMock.on(QueryCommand).resolves({});

        await handler(mockSQSEvent);

        expect(ddbMock.commandCalls(GetCommand)).toHaveLength(1);
        expect(ddbMock.commandCalls(QueryCommand)).toHaveLength(1);
        expect(apiGatewayMock.commandCalls(PostToConnectionCommand)).toHaveLength(0);
    });

    test('handles multiple S3 records in a single event', async () => {
        const mockS3Event: S3Event = {
            Records: [
                {
                    s3: {
                        object: {
                            key: 'abc123/preview1.jpg'
                        }
                    }
                },
                {
                    s3: {
                        object: {
                            key: 'def456/preview2.jpg'
                        }
                    }
                }
            ]
        } as any;

        const mockSQSEvent = createMockSQSEvent(mockS3Event);

        ddbMock.on(GetCommand)
            .resolvesOnce({ Item: { userId: 'user123', code: 'abc123' } })
            .resolvesOnce({ Item: { userId: 'user456', code: 'def456' } });

        ddbMock.on(QueryCommand)
            .resolvesOnce({ Items: [{ connectionId: 'conn123' }] })
            .resolvesOnce({ Items: [{ connectionId: 'conn456' }] });

        apiGatewayMock.on(PostToConnectionCommand).resolves({});

        await handler(mockSQSEvent);

        expect(ddbMock.commandCalls(GetCommand)).toHaveLength(2);
        expect(ddbMock.commandCalls(QueryCommand)).toHaveLength(2);
        expect(apiGatewayMock.commandCalls(PostToConnectionCommand)).toHaveLength(2);
    });

    test('handles errors gracefully', async () => {
        const mockS3Event: S3Event = {
            Records: [
                {
                    s3: {
                        object: {
                            key: 'abc123/preview.jpg'
                        }
                    }
                }
            ]
        } as any;

        const mockSQSEvent = createMockSQSEvent(mockS3Event);

        ddbMock.on(GetCommand).rejects(new Error('DynamoDB error'));

        const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();

        await handler(mockSQSEvent);

        expect(consoleErrorSpy).toHaveBeenCalledWith('Error processing S3 record:', expect.any(Error));
        expect(ddbMock.commandCalls(GetCommand)).toHaveLength(1);
        expect(ddbMock.commandCalls(QueryCommand)).toHaveLength(0);
        expect(apiGatewayMock.commandCalls(PostToConnectionCommand)).toHaveLength(0);

        consoleErrorSpy.mockRestore();
    });
});