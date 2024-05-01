const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { PutCommand, DynamoDBDocumentClient } = require("@aws-sdk/lib-dynamodb");

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));

exports.handler = async (event) => {
    console.debug('Received event:', JSON.stringify(event, null, 2));

    const env = process.env.environment;
    const tableName = `us-${env}-shortened-urls`;

    const userId = event.requestContext.authorizer.claims.sub;
    console.debug('UserId:', userId);

    const body = JSON.parse(event.body);
    console.debug('Body:', body);

    const shortenedUrl = {
        'code': generateCode(),
        'longUrl': body.longUrl,
        'userId': userId,
        'createdAt': new Date().getTime(),
    };

    try {
        const command = new PutCommand({
            TableName: tableName,
            Item: shortenedUrl
        });

        const result = await client.send(command);
        if (result['$metadata'].httpStatusCode == 200)
            return buildResponse(true, shortenedUrl);

        console.error('Result: ', result);
        return buildResponse(false, result);
    } catch (err) {
        console.error('Error: ', err);
        return buildResponse(false, err);
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
