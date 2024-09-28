const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const puppeteer = require("puppeteer-core");
const chromium = require('@sparticuz/chromium');

chromium.setHeadlessMode = true;
chromium.setGraphicsMode = false;

const AWSXRay = require('aws-xray-sdk-core');
const s3Client = AWSXRay.captureAWSv3Client(new S3Client());


exports.handler = async (event) => {
    console.debug('Received event:', JSON.stringify(event, null, 2));

    const start = Date.now();
    const browser = await puppeteer.launch({
        args: chromium.args,
        executablePath: await chromium.executablePath(),
        headless: chromium.headless,
    });
    console.debug('Browser launched in %dms', Date.now() - start);

    const env = process.env.ENVIRONMENT;
    const bucketName = `us-${env}-preview-storage`;

    console.debug('Publishing to bucket:', bucketName);

    try {
        for (const record of event.Records) {
            console.log('Record: ', JSON.stringify(record, null, 2));
            const body = JSON.parse(record.body);
            const newItem = JSON.parse(body.Message);
            console.log('NewItem:', newItem);
            const { longUrl, code } = newItem;

            await generateAndStorePreview(browser, longUrl, code, bucketName, 'desktop');
            await generateAndStorePreview(browser, longUrl, code, bucketName, 'mobile');
        }

        return buildResponse(true, 'Previews generated and stored successfully');
    } catch (error) {
        console.error('Error processing event:', error);
        return buildResponse(false, error.toString());
    } finally {
        await browser.close();
        console.debug('Browser closed');
    }
};

async function generateAndStorePreview(browser, url, code, bucketName, type) {

    let start = Date.now();
    const page = await browser.newPage();
    await page.setViewport(
        type === 'desktop'
            ? { width: 1280, height: 720 }
            : { width: 375, height: 667 }
    );
    await page.goto(url, { waitUntil: 'networkidle0' });
    console.debug('Page loaded in %dms (url: %s, type: %s)', Date.now() - start, url, type);

    start = Date.now();
    const screenshot = await page.screenshot({ encoding: 'base64' });
    console.debug('Screenshot taken in %dms', Date.now() - start);

    start = Date.now();
    const params = {
        Bucket: bucketName,
        Key: `${code}/${type}.png`,
        Body: Buffer.from(screenshot, 'base64'),
        ContentType: 'image/png'
    };
    const response = await s3Client.send(new PutObjectCommand(params));
    console.debug('PutObjectCommand in %dms Response: %j', Date.now() - start, response);
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
