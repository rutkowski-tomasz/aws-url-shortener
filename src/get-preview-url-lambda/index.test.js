const { S3Client } = require("@aws-sdk/client-s3");
const { mockClient } = require("aws-sdk-client-mock");

jest.mock("@aws-sdk/s3-request-presigner", () => ({
  getSignedUrl: jest.fn()
}));

const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { handler } = require("./index");

process.env.ENVIRONMENT = "dev";

const s3Mock = mockClient(S3Client);

describe('Unit Tests', () => {
  beforeEach(() => {
    s3Mock.reset();
    jest.clearAllMocks();
    getSignedUrl.mockResolvedValue("https://fake-signed-url.com");
  });

  test('successfully generates signed URLs for previews', async () => {
    const sampleEvent = {
      queryStringParameters: {
        code: "abc123"
      }
    };

    const response = await handler(sampleEvent);

    expect(response.statusCode).toEqual(200);
    const responseBody = JSON.parse(response.body);
    expect(responseBody.isSuccess).toBeTruthy();
    expect(responseBody.result).toEqual({
      desktopPreview: "https://fake-signed-url.com",
      mobilePreview: "https://fake-signed-url.com"
    });

    expect(getSignedUrl).toHaveBeenCalledTimes(2);
    
    const getSignedUrlCalls = getSignedUrl.mock.calls;
    expect(getSignedUrlCalls[0][1].input).toEqual(expect.objectContaining({
      Bucket: 'us-dev-shortened-urls-previews',
      Key: 'abc123/desktop.png'
    }));
    expect(getSignedUrlCalls[1][1].input).toEqual(expect.objectContaining({
      Bucket: 'us-dev-shortened-urls-previews',
      Key: 'abc123/mobile.png'
    }));
  });

  test('handles missing code parameter', async () => {
    const eventWithoutCode = { queryStringParameters: {} };

    const response = await handler(eventWithoutCode);

    expect(response.statusCode).toEqual(400);
    const responseBody = JSON.parse(response.body);
    expect(responseBody.isSuccess).toBeFalsy();
    expect(responseBody.error).toEqual('Missing code parameter');
  });

  test('handles getSignedUrl errors', async () => {
    getSignedUrl.mockRejectedValue(new Error('Failed to generate signed URL'));

    const sampleEvent = {
      queryStringParameters: {
        code: "abc123"
      }
    };

    const response = await handler(sampleEvent);

    expect(response.statusCode).toEqual(400);
    const responseBody = JSON.parse(response.body);
    expect(responseBody.isSuccess).toBeFalsy();
    expect(responseBody.error).toContain('Failed to generate signed URL');
  });
});

describe('Integration Test', () => {
  beforeAll(() => {
        jest.unmock("@aws-sdk/s3-request-presigner");
        const { getSignedUrl: actualGetSignedUrl } = jest.requireActual("@aws-sdk/s3-request-presigner");
        getSignedUrl.mockImplementation(actualGetSignedUrl);
  });

  test('integration test', async () => {
    const event = {
      queryStringParameters: {
        code: "123abcd"
      }
    };

    const result = await handler(event);
    expect(result.statusCode).toBe(200);

    const body = JSON.parse(result.body);
    expect(body.isSuccess).toBe(true);
    expect(body.result).toHaveProperty('desktopPreview');
    expect(body.result).toHaveProperty('mobilePreview');

    console.log('Desktop preview URL:', body.result.desktopPreview);
    console.log('Mobile preview URL:', body.result.mobilePreview);
  });
});
