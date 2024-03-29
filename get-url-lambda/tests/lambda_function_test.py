import unittest
from unittest.mock import patch
import sys

sys.path.append("./src")
from lambda_function import lambda_handler

class TestLambdaHandler(unittest.TestCase):
    @patch('lambda_function.table.get_item')
    def test_item_found(self, mock_get_item):
        mock_get_item.return_value = {
            'Item': {'code': '123', 'longUrl': 'https://example.com'}
        }

        event = {'code': '123'}
        context = {}
        response = lambda_handler(event, context)
        
        self.assertEqual(response['statusCode'], 302)
        self.assertIn('Location', response['headers'])
        self.assertEqual(response['headers']['Location'], 'https://example.com')

    @patch('lambda_function.table.get_item')
    def test_item_not_found(self, mock_get_item):
        mock_get_item.return_value = {}

        event = {'code': 'not_existing_code'}
        context = {}
        response = lambda_handler(event, context)
        
        self.assertEqual(response['statusCode'], 404)
        self.assertEqual(response['body'], 'URL not found')

    @patch('lambda_function.table.get_item')
    def test_client_error_exception(self, mock_get_item):
        from botocore.exceptions import ClientError
        mock_get_item.side_effect = ClientError(
            {"Error": {"Message": "DynamoDB ClientError occurred"}}, "get_item"
        )

        event = {'code': '123'}
        context = {}
        response = lambda_handler(event, context)
        
        self.assertEqual(response['statusCode'], 500)
        self.assertEqual(response['body'], 'Internal server error')

if __name__ == '__main__':
    unittest.main()
