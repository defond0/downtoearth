"""Router helper for API's using downtoearth."""
from downtoearth.exceptions import NotFoundException


class Router(object):
    """Routing object for given route_map.

    Args:
        route_map (optional[dict]): map of route to delegate
            ex.
                map = {
                    "GET:/v1/book": get_all,
                    "POST:/v1/book": post_book,
                    "GET:/v1/book/{isbn}": get_book,
                    "PUT:/v1/book/{isbn}": update_book,
                    "DELETE:/v1/book/{isbn}": remove_book
                }
        param_order (optional[list]): order of precedence for parameters
            This should include all three parameter types.
            ex. ['path', 'querystring', 'body']
            defaults to ['path', 'body', 'querystring']
    """
    DEFAULTS = {'param_order': ['path', 'body', 'querystring']}
    def __init__(self, route_map=None, param_order=None):
        if param_order is None:
            self.param_order = self.DEFAULTS['param_order']
        else:
            self.param_order = param_order
        self.route_map = {}
        if route_map and isinstance(route_map, dict):
            for k, v in route_map.items():
                self.add_full_route(k, v)

    def add_full_route(self, route, delegate):
        """Add route given route and delegate function.

        Args:
            route (str): route in format "VERB:route/{variables}"
            delegate (func): function to call
        """
        self.route_map[route] = delegate

    def add_route(self, verb, path, delegate):
        """Add route given verb, path, delegate function.

        Args:
            verb (str): HTTP verb
                ex. GET, POST
            path (str): path
            delegate (func): function to call
        """
        route = "{}:{}".format(verb, path)
        self.add_full_route(route, delegate)

    def route_request(self, event, context):
        """Route incoming request."""
        func = self.route_map.get(event['route'])
        if not func:
            raise ValueError("{}: route not found".format(event["route"]))
        params = {}
        for param_type in self.param_order[::-1]:
            params.update(event.get(param_type, {}))
        params['event'] = event
        result = func(**params)
        if result is None:
            raise NotFoundException('The resource could not be found.')
        return result
