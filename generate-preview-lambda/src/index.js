const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const chromium = require('chrome-aws-lambda');

const s3Client = new S3Client({});

exports.handler = async (event) => {
    console.debug('Received event:', JSON.stringify(event, null, 2));

    const env = process.env.environment;
    const bucketName = `us-${env}-shortened-urls-previews`;

    console.debug('Publishing to bucket:', bucketName);

    try {
        const promises = [];
        for (const record of event.Records) {
            console.log('Record: ', JSON.stringify(record, null, 2));
            const body = JSON.parse(record.body);
            const newItem = JSON.parse(body.Message);
            const { url, code } = newItem;

            promises.push(generateAndStorePreview(url, code, bucketName, 'desktop'));
            promises.push(generateAndStorePreview(url, code, bucketName, 'mobile'));
        }

        await Promise.all(promises);
        return buildResponse(true, 'Previews generated and stored successfully');
    } catch (error) {
        console.error('Error processing event:', error);
        return buildResponse(false, error.toString());
    }
};

async function generateAndStorePreview(url, code, bucketName, type) {
    const browser = await chromium.puppeteer.launch({
        args: chromium.args,
        defaultViewport: type === 'desktop' ? { width: 1280, height: 720 } : { width: 375, height: 667 },
        executablePath: await chromium.executablePath,
        headless: chromium.headless,
    });

    const page = await browser.newPage();
    await page.goto(url, { waitUntil: 'networkidle0' });
    const screenshot = await page.screenshot({ encoding: 'base64' });
    await browser.close();

    const params = {
        Bucket: bucketName,
        Key: `${code}/${type}.png`,
        Body: Buffer.from(screenshot, 'base64'),
        ContentType: 'image/png'
    };
    await s3Client.send(new PutObjectCommand(params));
}

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
