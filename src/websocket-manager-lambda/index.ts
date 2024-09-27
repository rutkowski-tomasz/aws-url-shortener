import { APIGatewayProxyEvent, APIGatewayProxyHandler, APIGatewayProxyResult } from 'aws-lambda';

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { PutCommand, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { Tracer } from '@aws-lambda-powertools/tracer';

const tracer = new Tracer();
const dynamoDbClient = tracer.captureAWSv3Client(new DynamoDBClient({}));

const { ENVIRONMENT } = process.env;
const TableName = `us-${ENVIRONMENT}-websocket-connections`;

export const handler: APIGatewayProxyHandler = async (
    event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
    const handlerSegment = tracer.getSegment()!.addNewSubsegment(`## ${process.env._HANDLER}`);
    tracer.setSegment(handlerSegment);

    console.log('Event: %j', event);

    if (!event.requestContext.authorizer) {
        throw new Error('Authorizer is not set');
    }

    if (!event.requestContext.connectionId) {
        throw new Error('ConnectionId is not set');
    }

    const eventType = event.requestContext.eventType;
    const userId = event.requestContext.authorizer.sub;
    const connectionId = event.requestContext.connectionId;

    tracer.putAnnotation('routeKey', event.requestContext.routeKey || '');
    tracer.putAnnotation('eventType', event.requestContext.eventType || '');
    tracer.putAnnotation('connectionId', event.requestContext.connectionId);
    tracer.putAnnotation('email', event.requestContext.authorizer.email);
    tracer.putAnnotation('sub', event.requestContext.authorizer.sub);

    try {

        if (eventType === 'CONNECT') {
            await connectUser(userId, connectionId);
        }
        else if (eventType === 'DISCONNECT') {
            await disconnectUser(connectionId);
        }

    } catch (err) {
        console.error('Error: %j', err);
        return { statusCode: 500, body: 'Internal server error' };
    }

    handlerSegment?.close();
    tracer.setSegment(handlerSegment?.parent);

    return { statusCode: 200, body: JSON.stringify({ connectionId: event.requestContext.connectionId }) };
};

const disconnectUser = async (connectionId: string) => {

    const command = new DeleteCommand({
        TableName,
        Key: { connectionId }
    });

    const result = await dynamoDbClient.send(command);
    console.debug('disconnecting user result: %j', result);
}

const connectUser = async (userId: string, connectionId: string) => {

    const command = new PutCommand({
        TableName,
        Item: {
            userId,
            connectionId,
            createdAt: new Date().getTime(),
        }
    });

    const result = await dynamoDbClient.send(command);
    console.debug('connecting user result: %j', result);
};
