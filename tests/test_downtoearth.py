import os
import unittest

from downtoearth.model import ApiModel


class DteArgs(object):
    def __init__(self, path, composable=False):
        self.input = path
        self.composable = composable


class MyTestCase(unittest.TestCase):
    def setUp(self):
        self.model = ApiModel(DteArgs('tests/api.json'))

    def test_load_name(self):
        self.assertEqual(self.model.json['Name'], 'DownToEarthApi')

    def test_load_api(self):
        self.assertEqual(self.model.json['Name'], 'DownToEarthApi')

    def test_auth_type(self):
        self.assertEqual(self.model.json['AuthType'], 'AWS_IAM')

    def test_can_output(self):
        output=self.model.render_terraform()
        test_dir = os.path.dirname(__file__)
        path = os.path.join(test_dir, 'test_api/', "main.tf")
        with open(path, "w") as f:
            f.write(output)
        print(output)


if __name__ == '__main__':
    unittest.main()
