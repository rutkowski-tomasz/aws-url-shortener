const { handler } = require("../src/index");

process.env.environment = "dev";

(async () => {
    const event = {
        queryStringParameters: {
            code: "123abcd"
        }
    };

    try {
        const result = await handler(event);
        console.log('Handler response:', JSON.stringify(result, null, 2));

        if (result.statusCode === 200) {
            const body = JSON.parse(result.body);
            if (body.isSuccess && body.result.desktopPreview && body.result.mobilePreview) {
                console.log('Integration test passed successfully!');
                console.log('Desktop preview URL:', body.result.desktopPreview);
                console.log('Mobile preview URL:', body.result.mobilePreview);
            } else {
                console.error('Integration test failed: Unexpected response structure');
            }
        } else {
            console.error('Integration test failed: Non-200 status code');
            console.error('Error:', result.body);
        }
    } catch (error) {
        console.error('Integration test failed with an error:', error);
    }
})();
