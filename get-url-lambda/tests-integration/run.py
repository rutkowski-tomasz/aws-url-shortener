import sys

sys.path.append("get-url-lambda/src")
from lambda_function import lambda_handler

sample_event = {
    "resource":"/get-url",
    "path":"/get-url",
    "httpMethod":"GET",
    "queryStringParameters":{"code":"X3adY9s_"},
    "multiValueQueryStringParameters":{"code":["X3adY9s_"]},
}

lambda_handler(sample_event)