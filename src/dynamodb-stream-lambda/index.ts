import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";
import { unmarshall } from "@aws-sdk/util-dynamodb";
import { DynamoDBStreamHandler } from 'aws-lambda';

const snsClient = new SNSClient({});

const { environment } = process.env;
const topicArn = `arn:aws:sns:eu-central-1:024853653660:us-${environment}-url-created`;

export const handler: DynamoDBStreamHandler = async (event) => {
    for (const record of event.Records) {
        console.log('Record: %j', record);

        if (record.eventName !== 'INSERT') {
            continue;
        }

        const newItem = unmarshall(record.dynamodb?.NewImage as any);
        const message = {
            Message: JSON.stringify(newItem),
            TopicArn: topicArn
        };

        const publishResult = await snsClient.send(new PublishCommand(message));
        console.log("publishResult: %j", publishResult);
    }
};