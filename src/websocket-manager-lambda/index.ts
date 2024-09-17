import { APIGatewayProxyEvent, APIGatewayProxyHandler, APIGatewayProxyResult } from 'aws-lambda';

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { PutCommand, DynamoDBDocumentClient, DeleteCommand } from "@aws-sdk/lib-dynamodb";

const dynamoDbClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const { ENVIRONMENT } = process.env;
const TableName = `us-${ENVIRONMENT}-websocket-connections`;

export const handler: APIGatewayProxyHandler = async (
    event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
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
