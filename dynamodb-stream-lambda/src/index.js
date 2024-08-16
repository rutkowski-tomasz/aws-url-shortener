const AWS = require('aws-sdk');
const sns = new AWS.SNS();


exports.handler = async (event) => {
    console.debug('Received event:', JSON.stringify(event, null, 2));

    const env = process.env.environment;
    const topicArn = `arn:aws:sns:eu-central-1:024853653660:us-${env}-url-created`;
    console.debug('Publishing to topic:', topicArn);

    try {
        for (const record of event.Records) {

            console.log('Record: ', JSON.stringify(record, null, 2));
            
            if (record.eventName === 'INSERT') {
                const newItem = AWS.DynamoDB.Converter.unmarshall(record.dynamodb.NewImage);
                const message = {
                    Message: JSON.stringify(newItem),
                    TopicArn: topicArn
                };

                try {
                    const publishResult = await sns.publish(message).promise();
                    console.log("Message sent to the topic", publishResult);
                } catch (error) {
                    console.error("Error sending message: ", error);
                    throw error;
                }
            }
        }

        return buildResponse(true, 'Stream events sent to SNS topic');
    } catch (error) {
        console.error('Error processing event:', error);
        return buildResponse(false, error.toString());
    }
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
