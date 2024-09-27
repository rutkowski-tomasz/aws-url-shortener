import { SQSEvent, S3Event } from "aws-lambda";
import { GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from "@aws-sdk/client-apigatewaymanagementapi";
import { Tracer } from '@aws-lambda-powertools/tracer';

const tracer = new Tracer();

const { ENVIRONMENT, AWS_REGION, WS_API_GATEWAY_ID } = process.env;

const apiGatewayManagementClient = tracer.captureAWSv3Client(new ApiGatewayManagementApiClient({
    region: AWS_REGION,
    endpoint: `https://${WS_API_GATEWAY_ID}.execute-api.${AWS_REGION}.amazonaws.com/${ENVIRONMENT}`,
}));

const dynamoDbClient = tracer.captureAWSv3Client(new DynamoDBClient({}));

const ShortenedUrlsTableName = `us-${ENVIRONMENT}-shortened-urls`;
const ConnectionsTableName = `us-${ENVIRONMENT}-websocket-connections`;



const getShortenedUrl = async (code: string) => {
    const command = new GetCommand({
        TableName: ShortenedUrlsTableName,
        Key: { code }
    });

    const result = await dynamoDbClient.send(command);
    return result.Item;
};

const getUserConnections = async (userId: string) => {
    const command = new QueryCommand({
        TableName: ConnectionsTableName,
        IndexName: "UserIdIndex",
        KeyConditionExpression: "userId = :userId",
        ExpressionAttributeValues: {
            ":userId": userId
        }
    });

    const result = await dynamoDbClient.send(command);
    return result;
};

const postToConnection = async (connectionId: string, data: any) => {
    const command = new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: JSON.stringify(data),
    });

    const result = await apiGatewayManagementClient.send(command);
    return result;
};

export const handler = async (event: SQSEvent) => {
    const handlerSegment = tracer.getSegment()!.addNewSubsegment(`## ${process.env._HANDLER}`);
    tracer.setSegment(handlerSegment);

    try {
        for (const record of event.Records) {

            const snsEvent = JSON.parse(record.body) as { Message: string };
            const s3Event = JSON.parse(snsEvent.Message) as S3Event;

            for (const s3Record of s3Event.Records) {

                const subSegment = handlerSegment.addNewSubsegment('### Record');
                tracer.setSegment(subSegment);

                const objectKey = s3Record.s3.object.key;
                const [code, file] = objectKey.split('/');
                tracer.putAnnotation('code', code);
                tracer.putAnnotation('file', file);

                console.log('Received %s creation of %s', code, file);

                try {
                    const shortenedUrl = await getShortenedUrl(code);
                    console.debug('shortenedUrl: %j', shortenedUrl);

                    if (!shortenedUrl) {
                        continue;
                    }

                    const userConnections = await getUserConnections(shortenedUrl.userId);
                    console.debug('userConnections: %j', userConnections);

                    if (!userConnections.Items) {
                        continue;
                    }

                    for (const connection of userConnections.Items) {
                        const data = {
                            eventType: 'PREVIEW_GENERATED',
                            code,
                            file
                        };
                        console.debug('data: %j', data);

                        await postToConnection(connection.connectionId, data);
                    }
                } catch (error) {
                    console.error('Error processing S3 record:', error);
                }

                subSegment?.close();
                tracer.setSegment(subSegment?.parent);
            }
        }
    } catch (error) {
        console.error('Error processing SQS event:', error);
    }

    handlerSegment?.close();
    tracer.setSegment(handlerSegment?.parent);
};