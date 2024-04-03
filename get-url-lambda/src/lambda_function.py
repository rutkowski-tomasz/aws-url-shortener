import boto3
import os
from botocore.exceptions import ClientError

environment = os.getenv('environment', 'dev')
table_name = f'us-{environment}-shortened-urls'

dynamodb = boto3.resource('dynamodb', region_name='eu-central-1')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    print('Received event: ', event)

    try:
        code = event['queryStringParameters']['code']

        response = table.get_item(Key={'code': code})
        
        if 'Item' in response:
            return build_response(302, '', response['Item']['longUrl'])
        else:
            return build_response(404, 'URL not found')
    except ClientError as e:
        print('Error: ', e)
        return build_response(500, 'Internal server error')


def build_response(status_code, body, location=None):
    response = {
        'isBase64Encoded': False,
        'statusCode': status_code,
        'body': body
    }

    if location:
        response['headers'] = {
            'Location': location
        }

    return response
