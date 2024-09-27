import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";
import { unmarshall } from "@aws-sdk/util-dynamodb";
import { DynamoDBStreamHandler } from 'aws-lambda';
import { Tracer } from '@aws-lambda-powertools/tracer';

const tracer = new Tracer();
const snsClient = tracer.captureAWSv3Client(new SNSClient({}));

const { ENVIRONMENT } = process.env;
const topicArn = `arn:aws:sns:eu-central-1:024853653660:us-${ENVIRONMENT}-url-created`;

export const handler: DynamoDBStreamHandler = async (event) => {
    const handlerSegment = tracer.getSegment()!.addNewSubsegment(`## ${process.env._HANDLER}`);
    tracer.setSegment(handlerSegment);

    for (const record of event.Records) {

        const subSegment = handlerSegment.addNewSubsegment('### Record');
        tracer.setSegment(subSegment);

        console.log('Record: %j', record);
        if (record.eventName !== 'INSERT') {
            continue;
        }

        const newItem = unmarshall(record.dynamodb?.NewImage as any);
        tracer.putAnnotation('code', newItem.code);

        const message = {
            Message: JSON.stringify(newItem),
            TopicArn: topicArn
        };

        const publishResult = await snsClient.send(new PublishCommand(message));
        console.log("publishResult: %j", publishResult);

        subSegment?.close();
        tracer.setSegment(subSegment?.parent);
    }

    handlerSegment?.close();
    tracer.setSegment(handlerSegment?.parent);
};