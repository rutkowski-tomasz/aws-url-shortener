import boto3
import os
from botocore.exceptions import ClientError

environment = os.getenv('environment', 'dev')
table_name = f'us-{environment}-shortened-urls'

dynamodb = boto3.resource('dynamodb', region_name='eu-central-1')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    try:
        code = event.get('code', '')
        
        response = table.get_item(Key={'code': code})
        
        if 'Item' in response:
            return {
                'statusCode': 302,
                'headers': {
                    'Location': response['Item']['longUrl']
                }
            }
        else:
            return {
                'statusCode': 404,
                'body': 'URL not found'
            }
    except ClientError as e:
        print(e.response['Error']['Message'])
        return {
            'statusCode': 500,
            'body': 'Internal server error'
        }
