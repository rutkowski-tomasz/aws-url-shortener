const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { PutCommand, DynamoDBDocumentClient } = require("@aws-sdk/lib-dynamodb");

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));

exports.handler = async (event) => {
    console.debug('Received event:', JSON.stringify(event, null, 2));

    const env = process.env.ENVIRONMENT;
    const tableName = `us-${env}-shortened-urls`;

    const userId = event.requestContext.authorizer.claims.sub;
    const body = JSON.parse(event.body);

    const input = {
        TableName: tableName,
        Item: {
            'code': generateCode(),
            'longUrl': body.longUrl,
            'userId': userId,
            'createdAt': new Date().getTime(),
        }
    };
    console.debug('Input: ', input);

    const command = new PutCommand(input);

    try {
        const result = await client.send(command);
        console.debug('Result: ', result);

        if (result['$metadata'].httpStatusCode !== 200) {
            throw new Error(`Failed to insert item into DynamoDB: ${JSON.stringify(result)}`);
        }

        return buildResponse(true, input.Item);
    } catch (err) {
        console.error('Error: ', err);
        return buildResponse(false, err.toString());
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

const buildResponse = (isSuccess, content) => ({
    statusCode: isSuccess ? 200 : 400,
    body: JSON.stringify({
        isSuccess,
        error: !isSuccess ? content : null,
        result: isSuccess ? content : null
    }),
    headers: {
        'Content-Type': 'application/json',
    },
});
