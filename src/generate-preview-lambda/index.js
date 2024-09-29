const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const puppeteer = require("puppeteer-core");
const chromium = require('@sparticuz/chromium');

chromium.setHeadlessMode = true;
chromium.setGraphicsMode = false;

const AWSXRay = require('aws-xray-sdk-core');
const s3Client = AWSXRay.captureAWSv3Client(new S3Client());

const { ENVIRONMENT } = process.env;
const bucketName = `us-${ENVIRONMENT}-preview-storage`;

exports.handler = async (event) => {

    console.log('Processing %d records', event.Records.length);

    const start = Date.now();
    const browser = await puppeteer.launch({
        args: chromium.args,
        executablePath: await chromium.executablePath(),
        headless: chromium.headless,
    });
    console.debug('Browser launched in %dms', Date.now() - start);

    for (const record of event.Records) {
        const body = JSON.parse(record.body);
        const newItem = JSON.parse(body.Message);
        console.log('NewItem:', newItem);
        const { longUrl, code } = newItem;

        await generateAndStorePreview(browser, longUrl, code, bucketName, 'desktop');
        await generateAndStorePreview(browser, longUrl, code, bucketName, 'mobile');
    }

    await browser.close();
};

const generateAndStorePreview = async (browser, url, code, bucketName, type) => {

    const start = Date.now();
    const page = await browser.newPage();
    await page.setViewport(
        type === 'desktop'
            ? { width: 1280, height: 720 }
            : { width: 375, height: 667 }
    );
    await page.goto(url, { waitUntil: 'networkidle0' });
    console.debug('Page loaded in %dms (url: %s, type: %s)', Date.now() - start, url, type);

    const screenshot = await page.screenshot({ encoding: 'base64' });

    const params = {
        Bucket: bucketName,
        Key: `${code}/${type}.png`,
        Body: Buffer.from(screenshot, 'base64'),
        ContentType: 'image/png'
    };
    const response = await s3Client.send(new PutObjectCommand(params));
    console.debug('PutObjectCommand Response: %j', response);
}
