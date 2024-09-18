import { APIGatewayRequestAuthorizerEvent } from 'aws-lambda';
import { decode, verify } from 'jsonwebtoken';
import jwkToPem from 'jwk-to-pem';

jest.mock('jwk-to-pem', () => ({
    __esModule: true,
    default: jest.fn(),
}));

jest.mock('jsonwebtoken');
jest.mock('jwk-to-pem');

const mockedDecode = decode as jest.MockedFunction<typeof decode>;
const mockedVerify = verify as jest.MockedFunction<typeof verify>;
const mockedJwkToPem = jwkToPem as jest.MockedFunction<typeof jwkToPem>;

process.env.USER_POOL_ID = 'test-user-pool';
process.env.AWS_REGION = 'us-east-1';
process.env.ENVIRONMENT = "dev";

import { handler, verifyClaims } from './index';

describe('Unit Tests', () => {
    beforeEach(() => {
        jest.resetAllMocks();
        global.fetch = jest.fn().mockResolvedValue({
            ok: true,
            json: () => Promise.resolve({
                keys: [{ kid: 'testKid', kty: 'RSA', n: 'test', e: 'AQAB' }]
            })
        });
    });

    describe('handler', () => {
        it('should throw an error if Authorization header is missing', async () => {
            const event = { headers: {} } as APIGatewayRequestAuthorizerEvent;
            await expect(handler(event, {} as any, {} as any)).rejects.toThrow('Missing Authorization header');
        });

        it('should throw an error if Authorization header is not a valid bearer token', async () => {
            const event = { headers: { Authorization: 'Invalid' } } as any;
            await expect(handler(event, {} as any, {} as any)).rejects.toThrow('Authorization header must be a valid bearer token');
        });

        it('should throw an error if token verification fails', async () => {
            const event = {
                headers: { Authorization: 'Bearer invalidToken' },
                methodArn: 'arn:aws:execute-api:us-east-1:123456789012:api-id/stage/method/resourcepath'
            } as any;
            mockedDecode.mockReturnValue({ header: { kid: 'testKid' } } as any);
            mockedVerify.mockImplementation(() => { throw new Error('Invalid token'); });
            await expect(handler(event, {} as any, {} as any)).rejects.toThrow('Invalid token');
        });

        it('should return a valid policy if token verification succeeds', async () => {
            const event = {
                headers: { Authorization: 'Bearer validToken' },
                methodArn: 'arn:aws:execute-api:us-east-1:123456789012:api-id/stage/method/resourcepath'
            } as any;
            mockedDecode.mockReturnValue({ header: { kid: 'testKid' } } as any);
            mockedVerify.mockReturnValue({ sub: 'testUser' } as any);
            mockedJwkToPem.mockReturnValue('testPem');

            const result = await handler(event, {} as any, {} as any);

            expect(result).toEqual({
                policyDocument: {
                    Version: '2012-10-17',
                    Statement: [
                        {
                            Action: 'execute-api:Invoke',
                            Effect: 'Allow',
                            Resource: event.methodArn,
                        },
                    ],
                },
                principalId: 'user',
                context: { sub: 'testUser' }
            });
        });
    });

    describe('verifyClaims', () => {
        it('should return null if token decoding fails', async () => {
            mockedDecode.mockReturnValue(null);
            const result = await verifyClaims('invalidToken');
            expect(result).toBeNull();
        });

        it('should throw an error if kid is not found in public keys', async () => {
            mockedDecode.mockReturnValue({ header: { kid: 'unknownKid' } } as any);
            await expect(verifyClaims('validToken')).rejects.toThrow('Public key ID "unknownKid" not found');
        });

        it('should return verified claims if token is valid', async () => {
            mockedDecode.mockReturnValue({ header: { kid: 'testKid' } } as any);
            mockedVerify.mockReturnValue({ sub: 'testUser' } as any);
            mockedJwkToPem.mockReturnValue('testPem');

            const result = await verifyClaims('validToken');
            expect(result).toEqual({ sub: 'testUser' });
        });
    });
});