const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { mockClient } = require("aws-sdk-client-mock");
const puppeteer = require("puppeteer-core");
const chromium = require('@sparticuz/chromium');

jest.mock('puppeteer-core');
jest.mock('@sparticuz/chromium');

const { handler } = require("../src/index");

process.env.environment = "dev";

const s3Mock = mockClient(S3Client);

const sampleEvent = {
  Records: [
    {
      body: JSON.stringify({
        Message: JSON.stringify({
          url: "https://example.com",
          code: "abc123"
        })
      })
    }
  ]
};

beforeEach(() => {
  s3Mock.reset();
  jest.clearAllMocks();
  
  // Mock chromium and puppeteer functions
  chromium.executablePath.mockResolvedValue('/path/to/chrome');
  puppeteer.launch.mockResolvedValue({
    newPage: jest.fn().mockResolvedValue({
      goto: jest.fn().mockResolvedValue(),
      screenshot: jest.fn().mockResolvedValue(Buffer.from('fake-screenshot')),
      close: jest.fn().mockResolvedValue()
    }),
    close: jest.fn().mockResolvedValue()
  });
});

test('successfully generates and stores previews', async () => {
  s3Mock.on(PutObjectCommand).resolves({});

  const response = await handler(sampleEvent);

  expect(response.statusCode).toEqual(200);
  const responseBody = JSON.parse(response.body);
  expect(responseBody.isSuccess).toBeTruthy();
  expect(responseBody.result).toEqual('Previews generated and stored successfully');

  // Check if puppeteer was called twice (for desktop and mobile)
  expect(puppeteer.launch).toHaveBeenCalledTimes(2);
  
  // Check if S3 PutObject was called twice (for desktop and mobile)
  expect(s3Mock.calls(PutObjectCommand)).toHaveLength(2);
  
  // Verify S3 PutObject calls
  const putObjectCalls = s3Mock.calls(PutObjectCommand);
  expect(putObjectCalls[0].args[0].input).toEqual(expect.objectContaining({
    Bucket: 'us-dev-shortened-urls-previews',
    Key: 'abc123/desktop.png',
    ContentType: 'image/png'
  }));
  expect(putObjectCalls[1].args[0].input).toEqual(expect.objectContaining({
    Bucket: 'us-dev-shortened-urls-previews',
    Key: 'abc123/mobile.png',
    ContentType: 'image/png'
  }));
});

test('handles errors correctly', async () => {
  puppeteer.launch.mockRejectedValue(new Error('Failed to launch browser'));

  const response = await handler(sampleEvent);

  expect(response.statusCode).toEqual(400);
  const responseBody = JSON.parse(response.body);
  expect(responseBody.isSuccess).toBeFalsy();
  expect(responseBody.error).toContain('Failed to launch browser');
});
