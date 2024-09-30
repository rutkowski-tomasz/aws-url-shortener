import boto3
import os
from botocore.exceptions import ClientError

environment = os.getenv('environment', 'dev')
table_name = f'us-{environment}-shortened-urls'

dynamodb = boto3.resource('dynamodb', region_name='eu-central-1')
table = dynamodb.Table(table_name)

def handle(event, context):
    print('Received event: ', event)

    try:
        code = event['queryStringParameters']['code']
        long_url = get_url(code)

        if long_url is None:
            return { 'statusCode': 404 }

        return { 'statusCode': 302, 'headers': { 'Location': long_url } }
    except ClientError as e:
        print('Error: ', e)
        return { 'statusCode': 500 }

def get_url(code):
    response = table.get_item(Key={'code': code})
    if 'Item' not in response:
        return None

    if 'archivedAt' in response['Item'] and response['Item']['archivedAt'] is not None:
        return None

    return response['Item']['longUrl']
