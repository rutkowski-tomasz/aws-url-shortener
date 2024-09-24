const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const puppeteer = require("puppeteer-core");
const chromium = require('@sparticuz/chromium');

chromium.setHeadlessMode = true;
chromium.setGraphicsMode = false;

const s3Client = new S3Client({});


exports.handler = async (event) => {
    console.debug('Received event:', JSON.stringify(event, null, 2));

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

            await generateAndStorePreview(longUrl, code, bucketName, 'desktop');
            await generateAndStorePreview(longUrl, code, bucketName, 'mobile');
        }

        return buildResponse(true, 'Previews generated and stored successfully');
    } catch (error) {
        console.error('Error processing event:', error);
        return buildResponse(false, error.toString());
    }
};

async function generateAndStorePreview(url, code, bucketName, type) {

    const browser = await puppeteer.launch({
        args: chromium.args,
        defaultViewport: type === 'desktop' ? { width: 1280, height: 720 } : { width: 375, height: 667 },
        executablePath: await chromium.executablePath(),
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
    console.debug('PutObjectCommand Params: ', params);

    const response = await s3Client.send(new PutObjectCommand(params));
    console.debug('PutObjectCommand Response: ', response);
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
