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

        response = table.get_item(Key={'code': code})

        if 'Item' not in response or response['Item']['archivedAt'] is not None:
            return { 'statusCode': 404 }

        return { 'statusCode': 302, 'headers': { 'Location': response['Item']['longUrl'] } }
    except ClientError as e:
        print('Error: ', e)
        return { 'statusCode': 500 }
