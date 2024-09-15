import unittest
from unittest.mock import patch
import sys
import os

from handler import handle

sample_event = {
    "resource":"/get-url",
    "path":"/get-url",
    "httpMethod":"GET",
    "queryStringParameters":{"code":"X3adY9s_"},
    "multiValueQueryStringParameters":{"code":["X3adY9s_"]},
}

class TestLambdaHandler(unittest.TestCase):
    @patch('handler.table.get_item')
    def test_item_found(self, mock_get_item):
        mock_get_item.return_value = {
            'Item': {'code': '123', 'longUrl': 'https://example.com'}
        }

        context = {}
        response = handle(sample_event, context)
        
        self.assertEqual(response['statusCode'], 302)
        self.assertIn('Location', response['headers'])
        self.assertEqual(response['headers']['Location'], 'https://example.com')

    @patch('handler.table.get_item')
    def test_item_not_found(self, mock_get_item):
        mock_get_item.return_value = {}

        context = {}
        response = handle(sample_event, context)
        
        self.assertEqual(response['statusCode'], 404)
        self.assertEqual(response['body'], 'URL not found')

    @patch('handler.table.get_item')
    def test_client_error_exception(self, mock_get_item):
        from botocore.exceptions import ClientError
        mock_get_item.side_effect = ClientError(
            {"Error": {"Message": "DynamoDB ClientError occurred"}}, "get_item"
        )

        context = {}
        response = handle(sample_event, context)
        
        self.assertEqual(response['statusCode'], 500)
        self.assertEqual(response['body'], 'Internal server error')

class TestLambdaHandlerIntegration(unittest.TestCase):
    @unittest.skipIf('CI' in os.environ, "Skipping integration test in CI environment")
    def test_integration(self):
        context = {}
        response = handle(sample_event, context)
        
        self.assertIn(response['statusCode'], [302, 404])
        if response['statusCode'] == 302:
            self.assertIn('Location', response['headers'])
        elif response['statusCode'] == 404:
            self.assertEqual(response['body'], 'URL not found')

if __name__ == '__main__':
    unittest.main()
