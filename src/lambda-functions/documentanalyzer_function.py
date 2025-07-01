import glob
import json
import os
import uuid
import boto3
import datetime
import random

from botocore.client import ClientError

def lambda_handler(event, context):
    dynamodb = boto3.client('dynamodb')
    assetID = str(uuid.uuid4())
    rec = json.loads(event['Records'][0]['body'])
    sourceS3Bucket = rec['Records'][0]['s3']['bucket']['name']
    sourceS3Key = rec['Records'][0]['s3']['object']['key']
    statusCode = 200
    body = {}
    
    try:
        # Storing asset information in DynamoDB
        dynamodb.put_item(TableName='mediaconvert-records', Item={'RecordId':{"S":assetID},'filename':{"S":sourceS3Key}})
    except Exception as e:
        print ('Exception: %s' % e)
        statusCode = 500
        raise

    finally:
        return {
            'statusCode': statusCode,
            'body': json.dumps(body),
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}
        }