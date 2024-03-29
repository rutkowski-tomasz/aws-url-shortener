import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ShortenedUrls')

def lambda_handler(event, context):
    try:
        code = event.get('code', '')
        
        response = table.get_item(Key={'code': code})
        item = response.get('Item', None)
        
        if item:
            return {
                'statusCode': 302,
                'headers': {
                    'Location': item['longUrl']
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
