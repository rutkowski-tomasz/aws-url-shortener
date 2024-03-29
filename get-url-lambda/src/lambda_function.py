import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ShortenedUrls')

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
