const { handler } = require("../src/index");

process.env.environment = "dev";


(async () => {
    const event = {
        Records: [
            {
                eventName: 'INSERT',
                dynamodb: {
                    NewImage: {
                        code: { S: 'abcd1234' },
                        longUrl: { S: 'https://example.com' },
                        userId: { S: 'user-001' },
                        createdAt: { N: '1234567890' }
                    }
                }
            }
        ]
    };

    await handler(event);
})();
