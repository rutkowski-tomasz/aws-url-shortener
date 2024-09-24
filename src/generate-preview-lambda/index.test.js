const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { mockClient } = require("aws-sdk-client-mock");
const { beforeEach, describe, test, expect, beforeAll, afterAll, jest } = require('@jest/globals');

jest.mock('puppeteer-core', () => ({
  launch: jest.fn(),
}));

jest.mock('@sparticuz/chromium', () => ({
  args: [],
  executablePath: jest.fn().mockResolvedValue('/path/to/chrome'),
  headless: true,
  setHeadlessMode: jest.fn(),
  setGraphicsMode: jest.fn(),
}));

const puppeteer = require("puppeteer-core");
const { handler } = require("./index");

process.env.ENVIRONMENT = "dev";

const s3Mock = mockClient(S3Client);

const sampleEvent = {
  Records: [
    {
      body: JSON.stringify({
        Message: JSON.stringify({
          longUrl: "https://example.com",
          code: "abc123"
        })
      })
    }
  ]
};

beforeEach(() => {
  s3Mock.reset();
  jest.clearAllMocks();
  
  puppeteer.launch.mockResolvedValue({
    newPage: jest.fn().mockResolvedValue({
      goto: jest.fn().mockResolvedValue(),
      screenshot: jest.fn().mockResolvedValue(Buffer.from('fake-screenshot')),
      close: jest.fn().mockResolvedValue()
    }),
    close: jest.fn().mockResolvedValue()
  });
});

describe('Unit Tests', () => {
  test('successfully generates and stores previews', async () => {
    s3Mock.on(PutObjectCommand).resolves({});

    const response = await handler(sampleEvent);

    expect(response.statusCode).toEqual(200);
    const responseBody = JSON.parse(response.body);
    expect(responseBody.isSuccess).toBeTruthy();
    expect(responseBody.result).toEqual('Previews generated and stored successfully');

    expect(puppeteer.launch).toHaveBeenCalledTimes(2);
    
    expect(s3Mock.calls(PutObjectCommand)).toHaveLength(2);
    
    const putObjectCalls = s3Mock.calls(PutObjectCommand);
    expect(putObjectCalls[0].args[0].input).toEqual(expect.objectContaining({
      Bucket: 'us-dev-preview-storage',
      Key: 'abc123/desktop.png',
      ContentType: 'image/png'
    }));
    expect(putObjectCalls[1].args[0].input).toEqual(expect.objectContaining({
      Bucket: 'us-dev-preview-storage',
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
});

describe('Integration Test', () => {
  beforeAll(() => {
    jest.unmock('puppeteer-core');
    jest.unmock('@sparticuz/chromium');
  });

  afterAll(() => {
    jest.mock('puppeteer-core', () => ({
      launch: jest.fn(),
    }));
    jest.mock('@sparticuz/chromium', () => ({
      args: [],
      executablePath: jest.fn().mockResolvedValue('/path/to/chrome'),
      headless: true,
      setHeadlessMode: jest.fn(),
      setGraphicsMode: jest.fn(),
    }));
  });

  test('integration test', async () => {
    const event = {
      Records: [{
        body: JSON.stringify({
          Message: JSON.stringify({
            longUrl: "https://example.com",
            code: "123abcd"
          })
        })
      }]
    };

    const result = await handler(event);
    expect(result.statusCode).toBe(200);

    const body = JSON.parse(result.body);
    expect(body.isSuccess).toBe(true);
    expect(body.result).toBe('Previews generated and stored successfully');
  });
});