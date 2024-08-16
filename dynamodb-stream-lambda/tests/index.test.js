const AWS = require('aws-sdk');
const { mockClient } = require("aws-sdk-client-mock");
const { handler } = require("../src/index"); // Assuming your Lambda handler is correctly exported from index.js

const s3Mock = mockClient(AWS.S3);

const sampleSQSEvent = {
    Records: [
        {
            body: JSON.stringify({
                Message: JSON.stringify({
                    url: "https://example.com/",
                    code: "uniqueCode123"
                })
            })
        }
    ]
};

beforeEach(() => {
    s3Mock.reset();
});

test('successfully generates previews and uploads to S3', async () => {
    s3Mock.on(AWS.S3.prototype.upload).resolves({
        Location: "https://example-bucket.s3.amazonaws.com/uniqueCode123/desktop.png",
        Bucket: "us-dev-previews",
        Key: "uniqueCode123/desktop.png"
    });

    const response = await handler(sampleSQSEvent);

    expect(response.statusCode).toEqual(200);
    expect(JSON.parse(response.body).isSuccess).toBeTruthy();
    expect(s3Mock.calls(AWS.S3.prototype.upload)).toHaveLength(2); // Expecting two uploads: one for desktop and one for mobile
    const desktopUploadArgs = s3Mock.calls(AWS.S3.prototype.upload)[0].args[0];
    const mobileUploadArgs = s3Mock.calls(AWS.S3.prototype.upload)[1].args[0];
    
    expect(desktopUploadArgs.Bucket).toEqual("us-dev-previews");
    expect(desktopUploadArgs.Key).toEqual("uniqueCode123/desktop.png");
    expect(mobileUploadArgs.Bucket).toEqual("us-dev-previews");
    expect(mobileUploadArgs.Key).toEqual("uniqueCode123/mobile.png");
});
