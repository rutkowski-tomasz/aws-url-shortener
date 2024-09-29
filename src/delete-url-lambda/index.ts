import { DynamoDBClient, DeleteItemCommand } from "@aws-sdk/client-dynamodb";
import { Tracer } from '@aws-lambda-powertools/tracer';
import { SQSHandler } from "aws-lambda";

const tracer = new Tracer();
const dynamoDbClient = tracer.captureAWSv3Client(new DynamoDBClient({}));

const { ENVIRONMENT } = process.env;

export const handler: SQSHandler = async (event) => {
    console.log('Event: %j', event);

    const handlerSegment = tracer.getSegment()!.addNewSubsegment(`## ${process.env._HANDLER}`);
    tracer.setSegment(handlerSegment);

    for (const record of event.Records) {

        const subSegment = handlerSegment.addNewSubsegment('### Record');
        tracer.setSegment(subSegment);

        const payload = JSON.parse(record.body);
        const code = payload.code;
        tracer.putAnnotation('code', code);

        console.log('Deleting URL: %s', code);
        await deleteUrl(code);

        subSegment?.close();
        tracer.setSegment(subSegment?.parent);
    }

    handlerSegment?.close();
    tracer.setSegment(handlerSegment?.parent);
};

const deleteUrl = async (code: string) => {
    const command = new DeleteItemCommand({
        TableName: `us-${ENVIRONMENT}-shortened-urls`,
        Key: {
            code: { S: code },
        },
    });

    return await dynamoDbClient.send(command);
};
