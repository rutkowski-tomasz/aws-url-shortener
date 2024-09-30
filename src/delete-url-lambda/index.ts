import { DynamoDBClient, UpdateItemCommand } from "@aws-sdk/client-dynamodb";
import { S3Client, DeleteObjectsCommand } from "@aws-sdk/client-s3";
import { Tracer } from '@aws-lambda-powertools/tracer';
import { SQSHandler } from "aws-lambda";
import { DeleteShortenedUrl } from "./schema/url_shortener/deleteshortenedurl/DeleteShortenedUrl";
import { AWSEvent } from "./schema/url_shortener/deleteshortenedurl/AWSEvent";

const tracer = new Tracer();
const dynamoDbClient = tracer.captureAWSv3Client(new DynamoDBClient({}));
const s3Client = tracer.captureAWSv3Client(new S3Client({}));

const { ENVIRONMENT } = process.env;

export const handler: SQSHandler = async (event) => {

    const handlerSegment = tracer.getSegment()!.addNewSubsegment(`## ${process.env._HANDLER}`);
    tracer.setSegment(handlerSegment);

    for (const record of event.Records) {

        const subSegment = handlerSegment.addNewSubsegment('### Record');
        tracer.setSegment(subSegment);

        const payload = JSON.parse(record.body) as AWSEvent<DeleteShortenedUrl>;
        const code = payload.detail.code;
        tracer.putAnnotation('code', code);

        console.log('Deleting URL: %s', code);

        const dynamoDbResult = await archiveUrl(code);
        console.log('DynamoDb Result: %j', dynamoDbResult);

        const s3Result = await deletePreviews(code);
        console.log('S3 Result: %j', s3Result);

        subSegment?.close();
        tracer.setSegment(subSegment?.parent);
    }

    handlerSegment?.close();
    tracer.setSegment(handlerSegment?.parent);
};

const archiveUrl = async (code: string) => {
    const command = new UpdateItemCommand({
        TableName: `us-${ENVIRONMENT}-shortened-urls`,
        Key: {
            code: { S: code },
        },
        UpdateExpression: "set archivedAt = :now",
        ExpressionAttributeValues: {
            ":now": { N: new Date().getTime().toString() }
        }
    });

    return await dynamoDbClient.send(command);
};

const deletePreviews = async (code: string) => {

    const params = {
        Bucket: `us-${ENVIRONMENT}-preview-storage`,
        Delete: {
            Objects: [
                { Key: `${code}/desktop.png` },
                { Key: `${code}/mobile.png` },
            ]
        }
    };
    const result = await s3Client.send(new DeleteObjectsCommand(params));

    if (result.Errors) {
        console.error('S3 Errors: %j', result.Errors);
        throw new Error('Failed to delete previews');
    }

    return result;
};

