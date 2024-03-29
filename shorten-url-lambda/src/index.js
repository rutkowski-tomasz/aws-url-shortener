const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { PutCommand, DynamoDBDocumentClient } = require("@aws-sdk/lib-dynamodb");

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));

exports.handler = async (event) => {
    console.debug('Received event:', JSON.stringify(event, null, 2));

    try {
        const command = new PutCommand({
            TableName: 'ShortenedUrls',
            Item: {
                'code': generateCode(),
                'longUrl': event.longUrl,
                'createdAt': new Date().toUTCString(),
            }
        });
        console.log('Command: ', command);

        const result = await client.send(command);
        return buildResponse(200, result);
    } catch (err) {
        console.error('Error: ', err);
        return buildResponse(400, err.message);
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
  
const buildResponse = (statusCode, body) => ({
    statusCode,
    body: JSON.stringify(body),
    headers: {
        'Content-Type': 'application/json',
    },
});
