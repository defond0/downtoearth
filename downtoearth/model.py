"""downtoearth API model."""
import json
import os
try:
    import subprocess32 as subprocess
except ImportError: # no subprocess32 / Python 3 = safe to use subprocess
    import subprocess

from jinja2 import PackageLoader, Environment

from downtoearth import default

try:
    # Modify raw_input to input if we're in Python 2.
    input = raw_input
except NameError as err:
    if 'name \'raw_input\' is not defined' not in err.args[0]:
        raise


class ApiModel(object):
    """downtoearth data model."""
    def __init__(self, args):
        self.args = args

        with open(args.input, 'r') as f:
            self.json = json.load(f)

        self._validate_config()
        self._build_api()

        self.name = self.json["Name"]

        self.jinja_env = Environment(loader=PackageLoader('downtoearth', 'templates'))

    def _validate_config(self):
        # TODO: use schematics or something to do nice first pass validation
        pass

    def _build_api(self):
        endpoint_keys = self.json["Api"].items()

        self.url_root = UrlTree()
        for endpoint, methods in endpoint_keys:
            self.url_root.process_url(endpoint, methods)

    def get_endpoints(self):
        """Get all paths that contain methods."""
        return self.url_root.get_endpoints()

    def get_api_template_variables(self):
        """Get API template variables."""
        ret = {
            "API_NAME": self.name,
            "API_DESCRIPTION": self.json.get('Description', ''),
            "API_REGION": self.json.get('Region', 'us-east-1'),
            "API_ACCOUNT": self.json['AccountNumber'],
            "AUTH_TYPE": self.json.get('AuthType', 'NONE'),
            "LAMBDA_ZIP": self.json['LambdaZip'],
            "LAMBDA_HANDLER": self.json['LambdaHandler'],
            "LAMBDA_MEMORY": self.json.get('LambdaMemory', 128),
            "LAMBDA_RUNTIME": self.json.get('LambdaRuntime', 'python2.7'),
            "LAMBDA_TIMEOUT": self.json.get('LambdaTimeout', 30),
            "CORS": self.json.get('Cors', True),
            "COMPOSABLE": self.args.composable,
            "STAGES": self.json.get('Stages', ['production'])
        }
        ret["STAGED"] = len(ret["STAGES"]) > 1

        if not isinstance(ret.get("STAGES"), list):
            raise TypeError("Stages must be a list of stage names")

        if "Roles" in self.json and ("Default" in self.json['Roles'] or "Policy" in self.json['Roles']):
            try:
                ret['DEFAULT_ROLE'] = json.dumps(self.json['Roles']['Default'])
            except KeyError:
                ret['DEFAULT_ROLE'] = json.dumps(self.json['Roles']['Policy'])
        else:
            ret['DEFAULT_ROLE'] = default.POLICY
        if "Roles" in self.json and "Trust" in self.json['Roles']:
            ret['ROLE_TRUST'] = json.dumps(self.json['Roles']['Trust'])
        else:
            ret['ROLE_TRUST'] = default.TRUST

        ret['ENDPOINTS'] = [e.get_endpoint_info(self.name) for e in self.get_endpoints()]

        # TODO: build up endpoints
        # ret['ENDPOINTS'] = [
        #     {
        #         "NAME": "test_resource",
        #         "PATH_PART": "test",
        #         "PARENT_RESOURCE_IDENTIFIER":
        #             "PARENT_ID" if False else "aws_api_gateway_rest_api.%s.root_resource_id"% self.json['Name'],
        #         "METHODS": [ "GET", "POST" ]
        #     }
        # ]
        return ret

    def render_terraform(self):
        """Return a rendered terraform template."""
        template = self.jinja_env.get_template('root.hcl')
        return template.render(**self.get_api_template_variables())

    def run_stage_deployments(self):
        pass

    def run_terraform(self):
        """Return a apply terraform after template rendered."""
        path = os.path.dirname(self.args.output)
        affirm = ['true', 'y', 'yes']
        decline = ['', 'false', 'n', 'no']
        tf_cmds = {
            'apply': 'terraform apply %s' % path,
            'plan': 'terraform plan %s' % path
        }
        quit_cmds = ['q', 'quit']
        while True:
            run_tf = input("Run terraform? [y/N] ").lower()
            if run_tf in affirm + decline:
                run_tf = run_tf not in decline
                break
            print('Try again.')
        if run_tf is True:
            while True:
                tf_cmd = input("terraform apply or plan? [apply/plan/quit] ")
                if tf_cmd in tf_cmds:
                    subprocess.call(tf_cmds[tf_cmd], shell=True)
                    break
                if tf_cmd.lower() in quit_cmds:
                    break
                print('Try again.')
                self.run_stage_deployments()
            return
        print('command to show plan:\n\t{}'.format(tf_cmds['plan']))
        print('command to apply:\n\t{}'.format(tf_cmds['apply']))


class UrlTree(object):
    def __init__(self):
        self.root = UrlNode("")
        self.chains = []

    def process_url(self, url, methods):
        if "//" in url:
            raise ValueError("problem in %s, cannot have a double slash" % url)

        # starting or trailing slashes mess up this split
        url = url.strip('/')

        parts = url.split('/')
        current_node = self.root
        last_part = parts[-1]
        for part in parts:
            existing_child = current_node.get_child(part)
            if existing_child:
                if part == last_part:
                    if existing_child.children:
                        existing_child.append_methods(methods)
                        # current_node = current_node.add_child(p, methods)
                    else:
                        raise ValueError("methods for this url %s have already been defined")

                current_node = existing_child
            else:
                if part == last_part:
                    current_node = current_node.add_child(part, methods)
                else:
                    current_node = current_node.add_child(part)

    def traverse_tree(self, node, depth=0):
        if node is None:
            return

        if not node.is_root():
            # the gateway provides it's own root node
            self.chains.append(node)

        for child in node.children:
            self.traverse_tree(child, depth + 1)

    def get_endpoints(self):
        self.traverse_tree(self.root)
        return self.chains


class UrlNode(object):
    def __init__(self, url, methods=None, parent=None):
        self.url = url
        if methods:
            self.methods = [m.upper() for m in methods]
        else:
            self.methods = []
        self.children = []
        self.parent = parent

    @property
    def prefix(self):
        parts = []
        if not self.parent:
            return ""

        current_node = self.parent
        while current_node:
            parts.insert(0, current_node.url)
            current_node = current_node.parent

        return "/".join(parts)

    @property
    def url_name(self):
        return self.full_url[1:].replace("/", "_").replace("{", "_").replace("}", "_")

    @property
    def full_url(self):
        return "/".join([self.prefix, self.url])

    def get_endpoint_info(self, api_name):
        if self.parent.is_root():
            parent_id = "aws_api_gateway_rest_api.%s.root_resource_id" % api_name
        else:
            parent_id = "aws_api_gateway_resource.%s.id" % self.parent.url_name

        return {
            "NAME": self.url_name,
            "PATH_PART": self.url,
            "PARENT_RESOURCE_IDENTIFIER": parent_id,
            "METHODS": self.methods,
            "METHODS_STRING": ",".join(self.methods)
        }

    def append_methods(self, methods):
        for m in [x.upper() for x in methods]:
            if m not in self.methods:
                self.methods.append(m)

    def add_child(self, url, methods=None):
        methods = methods if methods is not None else []
        node = UrlNode(url, methods, self)
        self.children.append(node)
        return node

    def is_leaf(self):
        return True if self.children else False

    def is_root(self):
        return False if self.parent else True

    def get_child(self, value):
        for child in self.children:
            if child.url == value:
                return child
        return None

    def has_child(self, value):
        for child in self.children:
            if child.url == value:
                return True
        return False

    def is_variable(self):
        return self.url[0] == "{" and self.url[-1] == "}"
