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