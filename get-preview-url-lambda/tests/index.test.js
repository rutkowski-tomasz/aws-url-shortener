const { S3Client, GetObjectCommand } = require("@aws-sdk/client-s3");
const { mockClient } = require("aws-sdk-client-mock");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

jest.mock("@aws-sdk/s3-request-presigner");

const { handler } = require("../src/index");

process.env.environment = "dev";

const s3Mock = mockClient(S3Client);

const sampleEvent = {
  queryStringParameters: {
    code: "abc123"
  }
};

beforeEach(() => {
  s3Mock.reset();
  jest.clearAllMocks();
  
  // Mock getSignedUrl function
  getSignedUrl.mockResolvedValue("https://fake-signed-url.com");
});

test('successfully generates signed URLs for previews', async () => {
  const response = await handler(sampleEvent);

  expect(response.statusCode).toEqual(200);
  const responseBody = JSON.parse(response.body);
  expect(responseBody.isSuccess).toBeTruthy();
  expect(responseBody.result).toEqual({
    desktopPreview: "https://fake-signed-url.com",
    mobilePreview: "https://fake-signed-url.com"
  });

  // Check if getSignedUrl was called twice (for desktop and mobile)
  expect(getSignedUrl).toHaveBeenCalledTimes(2);
  
  // Verify getSignedUrl calls
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

  const response = await handler(sampleEvent);

  expect(response.statusCode).toEqual(400);
  const responseBody = JSON.parse(response.body);
  expect(responseBody.isSuccess).toBeFalsy();
  expect(responseBody.error).toContain('Failed to generate signed URL');
});
