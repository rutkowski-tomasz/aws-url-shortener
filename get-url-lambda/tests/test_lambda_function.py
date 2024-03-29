import pytest
from moto import mock_dynamodb2
import boto3
from lambda_functions.get_url_lambda import lambda_handler

@pytest.fixture
def dynamodb_mock():
    with mock_dynamodb2():
        yield boto3.resource('dynamodb', region_name='us-east-1').create_table(
            TableName='ShortenedUrls',
            KeySchema=[{'AttributeName': 'code', 'KeyType': 'HASH'}],
            AttributeDefinitions=[{'AttributeName': 'code', 'AttributeType': 'S'}],
            BillingMode='PAY_PER_REQUEST'
        )

def test_redirect_to_long_url(dynamodb_mock):
    dynamodb_mock.put_item(Item={'code': 'testCode', 'longUrl': 'https://example.com'})

    response = lambda_handler({'code': 'testCode'}, None)
    assert response['statusCode'] == 302
    assert response['headers']['Location'] == 'https://example.com'

def test_url_not_found(dynamodb_mock):
    response = lambda_handler({'code': 'nonExistingCode'}, None)
    assert response['statusCode'] == 404
