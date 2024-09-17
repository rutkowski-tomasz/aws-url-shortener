const { S3Client, GetObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

const s3Client = new S3Client({});

exports.handler = async (event) => {
    console.debug('Received event:', JSON.stringify(event, null, 2));

    const env = process.env.ENVIRONMENT;
    const bucketName = `us-${env}-shortened-urls-previews`;

    console.debug('Getting from bucket:', bucketName);

    const code = event.queryStringParameters?.code;
    if (!code) {
        return buildResponse(false, 'Missing code parameter');
    }

    try {
        const desktopPreviewUrl = await generateSignedUrl(bucketName, code, 'desktop');
        const mobilePreviewUrl = await generateSignedUrl(bucketName, code, 'mobile');

        return buildResponse(true, {
            desktopPreview: desktopPreviewUrl,
            mobilePreview: mobilePreviewUrl
        });
    } catch (error) {
        console.error('Error processing event:', error);
        return buildResponse(false, error.toString());
    }
};

const generateSignedUrl = (bucketName, code, type, expirationSeconds = 60) => {
    const key = `${code}/${type}.png`;
    const command = new GetObjectCommand({ Bucket: bucketName, Key: key });
    const signedUrl = getSignedUrl(s3Client, command, { expiresIn: expirationSeconds });
    console.debug('Signed url: ', signedUrl);
    return signedUrl;
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
