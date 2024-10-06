const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { PutCommand } = require("@aws-sdk/lib-dynamodb");
const { SchedulerClient, CreateScheduleCommand } = require("@aws-sdk/client-scheduler");

const AWSXRay = require('aws-xray-sdk-core');
const dynamoDbClient = AWSXRay.captureAWSv3Client(new DynamoDBClient());
const schedulerClient = AWSXRay.captureAWSv3Client(new SchedulerClient());

const { ENVIRONMENT, EVENT_BUS_ARN, SCHEDULER_ROLE_ARN } = process.env;
const TTL = 3600;

exports.handler = async (event) => {

    try {
        const body = JSON.parse(event.body);
        const code = generateCode();
        const userId = event.requestContext.authorizer.claims.sub;

        await persist(code, body.longUrl, userId);
        await scheduleDeletion(code, userId);

        return {
            statusCode: 200,
            body: JSON.stringify({ code, ttl: TTL }),
            headers: {
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET,OPTIONS,POST,PUT',
                'Access-Control-Allow-Origin': '*'
            },
        };

    } catch (err) {
        console.error('Error: ', err);
        return {
            statusCode: 500,
            headers: {
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'GET,OPTIONS,POST,PUT',
                'Access-Control-Allow-Origin': '*'
            },
        };
    }
};

const generateCode = (length = 8) => {
    const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";
    let code = '';

    for (let i = 0; i < length; i++) {
        const randomIndex = Math.floor(Math.random() * chars.length);
        code += chars[randomIndex];
    }

    return code;
};

const scheduleDeletion = async (code, userId) => {
    const nowTime = new Date().getTime();
    const scheduleDate = new Date(nowTime + TTL * 1000).toISOString();
    const scheduleExpression = `at(${scheduleDate.slice(0, -'.000Z'.length)})`;
    console.debug('Scheduling deletion: ', scheduleExpression);

    await schedulerClient.send(new CreateScheduleCommand({
        Name: `us-${ENVIRONMENT}-delete-shortened-url-${code}`,
        ScheduleExpression: scheduleExpression,
        Target: {
            Arn: EVENT_BUS_ARN,
            RoleArn: SCHEDULER_ROLE_ARN,
            EventBridgeParameters: {
                DetailType: "DeleteShortenedUrl",
                Source: "url-shortener",
            },
            Input: JSON.stringify({ code, userId }),
        },
        FlexibleTimeWindow: { Mode: "OFF" },
        ActionAfterCompletion: "DELETE",
    }));
};

const persist = async (code, longUrl, userId) => {
    const command = new PutCommand({
        TableName: `us-${ENVIRONMENT}-shortened-urls`,
        Item: {
            code,
            longUrl,
            userId,
            createdAt: new Date().getTime(),
        }
    });

    const result = await dynamoDbClient.send(command);
    console.debug('Result: ', result);
};
