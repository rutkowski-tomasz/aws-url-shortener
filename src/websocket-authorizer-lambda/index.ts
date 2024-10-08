import { APIGatewayAuthorizerResult, APIGatewayAuthorizerResultContext, APIGatewayRequestAuthorizerEvent, APIGatewayRequestAuthorizerHandler } from 'aws-lambda';
import { decode, verify } from 'jsonwebtoken';
import jwkToPem from 'jwk-to-pem';
import { Tracer } from '@aws-lambda-powertools/tracer';

const tracer = new Tracer();
const { AWS_REGION, USER_POOL_ID } = process.env;

let pemEncodedPublicKeys: { [kid: string]: string };

export const handler: APIGatewayRequestAuthorizerHandler = async (
    event: APIGatewayRequestAuthorizerEvent
): Promise<APIGatewayAuthorizerResult> => {

    const handlerSegment = tracer.getSegment()!.addNewSubsegment(`## ${process.env._HANDLER}`);
    tracer.setSegment(handlerSegment);

    console.log('event: %j', event);

    if (!USER_POOL_ID) {
        throw new Error('Missing USER_POOL_ID environment variable');
    }

    const authorizationHeader = event.headers?.['Authorization'];
    if (!authorizationHeader) {
        throw new Error('Missing Authorization header');
    }

    if (authorizationHeader.substring(0, 7) !== 'Bearer ') {
        throw new Error('Authorization header must be a valid bearer token');
    }

    const token = authorizationHeader.substring(7);
    const claims = await verifyClaims(token) as APIGatewayAuthorizerResultContext;
    if (!claims) {
        throw new Error('Unauthorized');
    }

    tracer.putAnnotation('sub', claims.sub as string);
    tracer.putAnnotation('email', claims.email as string);

    const policy = generatePolicy(event.methodArn, claims);

    console.log('policy: %j', policy);

    handlerSegment?.close();
    tracer.setSegment(handlerSegment?.parent);

    return policy;
};

const loadPemEncodedPublicKeys = async () => {
    const jwksUrl = `https://cognito-idp.${AWS_REGION}.amazonaws.com/${USER_POOL_ID}/.well-known/jwks.json`;

    const response = await fetch(jwksUrl);
    if (!response.ok) {
        throw new Error(`Unable to fetch JWKS using URL ${jwksUrl}`);
    }

    const json = await response.json() as { keys: [{ kid: string, kty: 'RSA', n: string, e: string }]};

    pemEncodedPublicKeys = {};
    for (const { kid, kty, n, e } of json.keys) {
        pemEncodedPublicKeys[kid] = jwkToPem({ kty, e, n });
    }
    console.debug('Loaded keys: %j', pemEncodedPublicKeys);
};

export const verifyClaims = async (token: string) => {
    const decodedJwt = decode(token, { complete: true });

    if (!decodedJwt || !decodedJwt.header || !decodedJwt.header.kid) {
        return null;
    }

    if (!pemEncodedPublicKeys) {
        await loadPemEncodedPublicKeys();
    }

    const kid = decodedJwt.header.kid;
    if (!(kid in pemEncodedPublicKeys)) {
        throw new Error(`Public key ID "${kid}" not found for User Pool ID "${USER_POOL_ID}" in "${AWS_REGION}" region`);
    }

    return verify(token, pemEncodedPublicKeys[kid]);
};

const generatePolicy = (
    resource: string,
    context: APIGatewayAuthorizerResultContext
): APIGatewayAuthorizerResult => ({
    policyDocument: {
        Version: '2012-10-17',
        Statement: [
            {
                Action: 'execute-api:Invoke',
                Effect: 'Allow',
                Resource: resource,
            },
        ],
    },
    principalId: 'user',
    context
});
