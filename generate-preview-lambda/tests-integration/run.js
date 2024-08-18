const { handler } = require("../src/index");

process.env.environment = "dev";


(async () => {
    const event = {
        Records: [{
            body: JSON.stringify({
                Message: JSON.stringify({
                    url: "https://example.com",
                    code: "123abcd"
                })
            })
        }]
    };

    await handler(event);
})();
