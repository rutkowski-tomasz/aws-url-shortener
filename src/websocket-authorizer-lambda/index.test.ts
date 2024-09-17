import { APIGatewayRequestAuthorizerEvent, Context, Callback, APIGatewayAuthorizerResult } from 'aws-lambda';
import { beforeEach, describe, test, expect, jest } from '@jest/globals';
import jwt from 'jsonwebtoken';
import jwkToPem from 'jwk-to-pem';

process.env.AWS_REGION = 'us-east-1';
process.env.USER_POOL_ID = 'us-east-1_testpool';

jest.mock('jsonwebtoken');
jest.mock('jwk-to-pem');

import { handler } from './index';

global.fetch = jest.fn() as jest.MockedFunction<typeof fetch>;

describe('Unit Tests', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        (global.fetch as jest.Mock).mockClear();
    });

//     test('successfully authorizes a valid token', async () => {
//         const mockToken = 'valid.jwt.token';
//         const mockClaims = { sub: 'user123', email: 'user@example.com' };
//         const mockEvent: APIGatewayRequestAuthorizerEvent = {
//             type: 'REQUEST',
//             methodArn: 'arn:aws:execute-api:region:account:api-id/stage/method/resource-path',
//             headers: { Authorization: `Bearer ${mockToken}` },
//         } as any;

//         (jwkToPem as jest.Mock).mockReturnValue('mock-pem-key');

//         (jwt.decode as jest.Mock).mockReturnValue({ header: { kid: 'test-kid' } });
//         (jwt.verify as jest.Mock).mockReturnValue(mockClaims);

//         (global.fetch as jest.Mock).mockResolvedValue({
//             ok: true,
//             json: () => Promise.resolve({
//                 keys: [{ kid: 'test-kid', kty: 'RSA', n: 'test-n', e: 'test-e' }]
//             }),
//         } as never);

//         const result = await handler(mockEvent, {} as Context, {} as Callback) as APIGatewayAuthorizerResult;

//         expect(result.policyDocument.Statement[0].Effect).toBe('Allow');
//         expect(result.context).toEqual(mockClaims);
//     });

    test('throws error for missing Authorization header', async () => {
        const mockEvent: APIGatewayRequestAuthorizerEvent = {
            type: 'REQUEST',
            methodArn: 'arn:aws:execute-api:region:account:api-id/stage/method/resource-path',
            headers: {},
        } as any;

        await expect(handler(mockEvent, {} as Context, {} as Callback)).rejects.toThrow('Missing Authorization header');
    });

    test('throws error for invalid bearer token', async () => {
        const mockEvent: APIGatewayRequestAuthorizerEvent = {
            type: 'REQUEST',
            methodArn: 'arn:aws:execute-api:region:account:api-id/stage/method/resource-path',
            headers: { Authorization: 'Invalid token' },
        } as any;

        await expect(handler(mockEvent, {} as Context, {} as Callback)).rejects.toThrow('Authorization header must be a valid bearer token');
    });

//     test('throws error for unauthorized token', async () => {
//         const mockToken = 'invalid.jwt.token';
//         const mockEvent: APIGatewayRequestAuthorizerEvent = {
//             type: 'REQUEST',
//             methodArn: 'arn:aws:execute-api:region:account:api-id/stage/method/resource-path',
//             headers: { Authorization: `Bearer ${mockToken}` },
//         } as any;

//         (jwt.decode as jest.Mock).mockReturnValue(null);

//         await expect(handler(mockEvent, {} as Context, {} as Callback)).rejects.toThrow('Unauthorized');
//     });
});

// describe('Integration Test', () => {
//     beforeAll(() => {
//         jest.resetAllMocks();
//     });

//     test('integration test', async () => {
//         const mockToken = 'valid.integration.token';
//         const mockEvent: APIGatewayRequestAuthorizerEvent = {
//             type: 'REQUEST',
//             methodArn: 'arn:aws:execute-api:region:account:api-id/stage/method/resource-path',
//             headers: { Authorization: `Bearer ${mockToken}` },
//         } as any;

//         (global.fetch as jest.Mock).mockResolvedValue({
//             json: () => Promise.resolve({
//                 keys: [{ kid: 'test-kid', kty: 'RSA', n: 'test-n', e: 'test-e' }]
//             }),
//         } as Response);

//         await handler(mockEvent, {} as Context, {} as Callback);
//     });
// });