import { APIGatewayProxyEvent, Context, Callback, APIGatewayProxyResult } from 'aws-lambda';
import { mockClient } from "aws-sdk-client-mock";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { PutCommand, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { beforeEach, describe, test, expect } from '@jest/globals';

const ddbMock = mockClient(DynamoDBClient);

process.env.ENVIRONMENT = 'dev';

import { handler } from './index';

describe('Unit Tests', () => {
    beforeEach(() => {
        ddbMock.reset();
    });

    const createMockEvent = (eventType: string, connectionId: string): APIGatewayProxyEvent => ({
        requestContext: {
            eventType,
            connectionId,
            authorizer: {
                sub: 'user123'
            }
        },
    } as any);

    test('successfully handles CONNECT event', async () => {
        const mockEvent = createMockEvent('CONNECT', 'test-connection-id');

        ddbMock.on(PutCommand).resolves({});

        const result = await handler(mockEvent, {} as Context, {} as Callback) as APIGatewayProxyResult;

        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body)).toEqual({ connectionId: 'test-connection-id' });
        expect(ddbMock.commandCalls(PutCommand)).toHaveLength(1);
        expect(ddbMock.commandCalls(PutCommand)[0].args[0].input).toMatchObject({
            TableName: 'us-dev-websocket-connections',
            Item: {
                userId: 'user123',
                connectionId: 'test-connection-id',
                createdAt: expect.any(Number),
            }
        });
    });

    test('successfully handles DISCONNECT event', async () => {
        const mockEvent = createMockEvent('DISCONNECT', 'test-connection-id');

        ddbMock.on(DeleteCommand).resolves({});

        const result = await handler(mockEvent, {} as Context, {} as Callback) as APIGatewayProxyResult;

        expect(result.statusCode).toBe(200);
        expect(JSON.parse(result.body)).toEqual({ connectionId: 'test-connection-id' });
        expect(ddbMock.commandCalls(DeleteCommand)).toHaveLength(1);
        expect(ddbMock.commandCalls(DeleteCommand)[0].args[0].input).toMatchObject({
            TableName: 'us-dev-websocket-connections',
            Key: { connectionId: 'test-connection-id' }
        });
    });

    test('throws error when authorizer is not set', async () => {
        const mockEvent = {
            requestContext: {
                eventType: 'CONNECT',
                connectionId: 'test-connection-id'
            }
        } as any;

        await expect(handler(mockEvent, {} as Context, {} as Callback)).rejects.toThrow('Authorizer is not set');
    });

    test('throws error when connectionId is not set', async () => {
        const mockEvent = {
            requestContext: {
                eventType: 'CONNECT',
                authorizer: { sub: 'user123' }
            }
        } as any;

        await expect(handler(mockEvent, {} as Context, {} as Callback)).rejects.toThrow('ConnectionId is not set');
    });

    test('handles DynamoDB errors gracefully', async () => {
        const mockEvent = createMockEvent('CONNECT', 'test-connection-id');

        ddbMock.on(PutCommand).rejects(new Error('DynamoDB error'));

        const result = await handler(mockEvent, {} as Context, {} as Callback) as APIGatewayProxyResult;

        expect(result.statusCode).toBe(500);
        expect(result.body).toBe('Internal server error');
    });
});

describe('Integration Test', () => {
    beforeAll(() => {
        ddbMock.restore();
    });

    afterAll(() => {
        mockClient(DynamoDBClient);
    });

    test('connect test', async () => {
        const event = {
            "requestContext": {
                "routeKey": "$connect",
                "authorizer": {
                    "sub": "93f4f812-b0d1-707c-1703-f0c61a56e25a",
                },
                "eventType": "CONNECT",
                "connectionId": "eP96OfayFiACHMw=",
            }
        };

        await handler(event as any, {} as Context, {} as Callback);
    });

    test('disconnect test', async () => {
        const event = {
            "requestContext": {
                "routeKey": "$disconnect",
                "authorizer": {
                    "sub": "93f4f812-b0d1-707c-1703-f0c61a56e25a",
                },
                "eventType": "DISCONNECT",
                "connectionId": "eP96OfayFiACHMw=",
            }
        };

        await handler(event as any, {} as Context, {} as Callback);
    });
});