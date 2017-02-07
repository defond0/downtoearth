=====
Usage
=====

.. highlight:: python

api.json
--------

A json file is used to define your api. From this, downtoearth will generate a terraform document.

.. code-block:: json

    {
      "Name": "DownToEarthApi",
      "Description": "test API for the downtoearth tool",
      "AccountNumber": "123456789012",
      "LambdaZip": "dist/api-lambda.zip",
      "LambdaHandler": "lambda_handler.lambda_handler",
      "LambdaRuntime": "python2.7",
      "Roles": {
        "MyRole": {
          "PolicyDoc": "GoesHere"
        }
      },
      "Api":{
        "/api/X/{1}": ["GET"],
        "/api/X": ["GET", "POST"],

        "/api/Y": ["GET", "POST"],
        "/api/Y/{1}": ["GET"]
      }
    }

lambda
------

The event dictionary gets filled with a "route" element that contains a
string representing the verb and endpoint hit.

::

    VERB:/api/my/endpoint/{my_variable}

This simple example will show you how to map that name to a python
function.

::

    def get_y(event, context):
        return dict(oh="yaaaaa!")

    function_mapping = {
        "GET:/api/Y": get_y
    }


    def route_request(event, context):
        if "route" not in event:
            raise ValueError("must have 'route' in event dictionary")

        if event["route"] not in function_mapping:
            raise ValueError("cannot find {0} in function mapping".format(event["route"]))

        func = function_mapping[event["route"]]
        return func(event, context)


    def lambda_handler(event, context=None):
        print("event: %s"%event)
        return route_request(event, context)

TODO: it'd be awesome if this worked with decorators like flask or
chalice.

Router
------

If your API is straightforward there is no reason to write your own router.
We provide one. Your lambda code could be as simple as:

::

    from downtoearth.router import Router

    ROUTE_MAP = {
        "GET:/v1/book": get_all,
        "POST:/v1/book": post_book,
        "GET:/v1/book/{isbn}": get_book,
        "PUT:/v1/book/{isbn}": update_book,
        "DELETE:/v1/book/{isbn}": remove_book
    }


    def handle_event(event, context):
        """Route and handle incoming event."""
        router = Router(ROUTE_MAP)
        return router.route_request(event, context)

Returning different status codes
--------------------------------

The generated API gateway includes a number of common response codes
along with their official descriptions. To return a non-200 OK HTTP
code, raise an exception with an official description bracketed at the
beginning. For example, to return a 404:

::

    if not found:
        raise ValueError('[Not Found] Could not find %s' % item_id)

Or you can nicely handle responses from DynamoDB:

::

    try:
        db.put_item(Item=item,
                    ConditionExpression='attribute_not_exists(item_id)')
    except ClientError:
        if 'ConditionalCheckFailedException' in e.args[0]:
            raise ValueError('[Conflict] %s already exists' % item['id'])
        else:
            raise Exception('[Internal Server Error] An unknown error occurred.  Info: %s' % e.args[0])

The currently supported status codes are defined in rfc7231codes, in
api\_endpoints.hcl. To add support for a new status code, extend that
tuple with a (code, description) pair.

Currently, there is no way to return additional headers or a custom
body. All non-200 integration responses just contain the lambda output
errorMessage field.

Exceptions
----------

We also provide exceptions helpers for you. If you are using the provided
router you won't need this. If you write your own router, use them like this.

::

    from downtoearth.exceptions import NotFoundException

    if not found:
        raise NotFoundException('Could not find %s' % item_id)

Creating the Terraform
----------------------

::

    cli.py INPUT_API_DEFITION_PATH OUTPUT_TERRAFORM_PATH
    # or if you have it installed
    downtoearth INPUT_API_DEFITION_PATH OUTPUT_TERRAFORM_PATH

Stages, Deployment, and You
---------------------------

By default, downtoearth with create a single "production" stage. Create
multiple stages by providing an array of names to the Stages key of the
config

::

    "Stages": ["production", "develop"]

Applying the terraform created by downtoearth will create an alias in
your lambda for each stage you defined.

Now here's the tricky part: because stages and lambda versions and
aliases are so weird, we have to update the lambda that powers a
specific stage outside of terraform. This is just easier, I promise. And
hopefully, the shape of your API will change much less often than the
code that powers it, so you won't have to constantly churn terraform
applies just because you fixed a bug in your code.

Your stage aliases are initially set up to point to the $LATEST version.
When you wanna push fresh code to a stage, publish a version of your
code, update the alias to point to that version. We will soon provide a
downtoearth cli command to help you deploy a zip to a stage, but for
now, here's a little ``./deploy.sh STAGE`` script to help

::

    #!/usr/bin/env bash
    STAGE=$1
    aws lambda update-function-code --function-name MY_FUNCTION_ROOT --zip-file fileb://MY_ZIP.zip
    VERSION="$(aws lambda  --region=us-east-1 publish-version --function-name MY_FUNCTION_ROOT | jq -r .Version)"
    echo "Created version #$VERSION"
    aws lambda update-alias --function-name MY_FUNCTION_ROOT --name $STAGE --function-version $VERSION
