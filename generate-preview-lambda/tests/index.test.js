const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { mockClient } = require('aws-sdk-client-mock');
const { handler } = require("../src/index");
const chromium = require('chrome-aws-lambda');

process.env.environment = "dev";

jest.mock('chrome-aws-lambda', () => ({
  puppeteer: {
    launch: jest.fn()
  }
}));

const s3Mock = mockClient(S3Client);

describe('Lambda Function Tests', () => {
  beforeEach(() => {
    s3Mock.reset();
    chromium.puppeteer.launch.mockReset();
  });

  const event = {
    Records: [{
      body: JSON.stringify({
        Message: JSON.stringify({
          url: "https://example.com",
          code: "123abc"
        })
      })
    }]
  };

  test('successfully processes event and stores previews', async () => {
    const browser = {
      newPage: jest.fn(() => ({
        goto: jest.fn().mockResolvedValue(),
        screenshot: jest.fn().mockResolvedValue('fakeimagebase64'),
        close: jest.fn()
      })),
      close: jest.fn()
    };
    chromium.puppeteer.launch.mockResolvedValue(browser);

    s3Mock.on(PutObjectCommand).resolves({});

    const response = await handler(event);

    expect(chromium.puppeteer.launch).toHaveBeenCalled();
    expect(browser.newPage).toHaveBeenCalledTimes(2); // Once for desktop, once for mobile
    expect(s3Mock.calls(PutObjectCommand)).toHaveLength(2);
    expect(response.statusCode).toEqual(200);
    expect(JSON.parse(response.body).isSuccess).toBeTruthy();
  });

  test('handles errors correctly', async () => {
    chromium.puppeteer.launch.mockRejectedValue(new Error("Failed to launch browser"));

    const response = await handler(event);

    expect(response.statusCode).toEqual(400);
    expect(JSON.parse(response.body).isSuccess).toBeFalsy();
    expect(JSON.parse(response.body).error).toContain("Failed to launch browser");
  });
});
