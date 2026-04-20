import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE_NAME'])

def lambda_handler(event, context):
    response = table.get_item(Key={'id': '0'})

    item = response.get('Item')

    if item and 'views' in item:
        views = int(item['views'])
    else:
        views = 0

    views += 1

    table.put_item(Item={
        'id': '0',
        'views': views
    })

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({"views": views})
    }
