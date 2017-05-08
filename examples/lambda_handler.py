def get_all(event, context):
    return dict(response="Successfully retrieved all books.")


def get_book(event, context):
    return dict(response="Successfully retrieved book by isbn.")


def post_book(event, context):
    return dict(response="Successfully added book.")


def update_book(event, context):
    return dict(response="Successfully updated book.")


def remove_book(event, context):
    return dict(response="Successfully removed book.")


function_mapping = {
    "GET:/v1/book": get_all,
    "POST:/v1/book": post_book,
    "GET:/v1/book/{isbn}": get_book,
    "PUT:/v1/book/{isbn}": update_book,
    "DELETE:/v1/book/{isbn}": remove_book
}


def route_request(event, context):
    if "route" not in event:
        raise ValueError("must have 'route' in event dictionary")

    if event["route"] not in function_mapping:
        raise ValueError("cannot find {0} in function mapping".format(event["route"]))

    func = function_mapping[event["route"]]
    return func(event, context)


def lambda_handler(event, context=None):
    print("event: %s" % event)
    return route_request(event, context)
