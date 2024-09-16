import { APIGatewayProxyHandler, APIGatewayProxyResult } from 'aws-lambda';

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { PutCommand, DynamoDBDocumentClient, GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const dynamoDbClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

const { ENVIRONMENT } = process.env;
const TableName = `us-${ENVIRONMENT}-websocket-connections`;

export const handler: APIGatewayProxyHandler = async (event): Promise<APIGatewayProxyResult> => {
    console.log('Event: %j', event);

    const routeKey = event.requestContext.routeKey;
    console.log('routeKey: %j', routeKey);
    const eventType = event.requestContext.eventType;
    console.log('eventType: %j', eventType);

    if (!event.requestContext.authorizer) {
        throw new Error('Authorizer is not set');
    }

    if (!event.requestContext.connectionId) {
        throw new Error('ConnectionId is not set');
    }

    try {
        const userId = event.requestContext.authorizer.sub;
        const connectionId = event.requestContext.connectionId;

        console.debug('userId: %j', userId);
        console.debug('connectionId: %j', connectionId);

        const userConnections = await getUserConnections(userId);
        console.debug('userConnections: %j', userConnections);

        if (!userConnections) {
            console.debug('Inserting new connection');
            const command = buildInsertConnectionCommand(userId, connectionId);
            console.debug('command: %j', command);
            const result = await dynamoDbClient.send(command);
            console.debug('result: %j', result);
        } else {
            console.debug('Appending new connection');
            const command = buildAddConnectionCommand(userId, [...userConnections.Item.connections, connectionId]);
            console.debug('command: %j', command);
            const result = await dynamoDbClient.send(command);
            console.debug('result: %j', result);
        }

    } catch (err) {
        console.error('Error: %j', err);
        return { statusCode: 500, body: 'Internal server error' };
    }

    return { statusCode: 200, body: JSON.stringify({ connectionId: event.requestContext.connectionId }) };
};

const getUserConnections = async (userId: string) => {

    const command = new GetCommand({
        TableName,
        Key: { userId }
    })

    const result = await dynamoDbClient.send(command);
    console.debug('result: %j', result);

    return result.Item;
}

const buildInsertConnectionCommand = (userId: string, connectionId: string) => new PutCommand({
    TableName,
    Item: {
        userId,
        connectionIds: [connectionId],
        createdAt: new Date().getTime(),
    }
})

const buildAddConnectionCommand = (userId: string, connectionIds: string[]) => new UpdateCommand({
    TableName,
    Key: { userId },
    UpdateExpression: "set connectionIds = :connectionIds",
    ExpressionAttributeValues: {
        ":connectionIds": connectionIds,
    },
    ReturnValues: "ALL_NEW",
});


