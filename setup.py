#!/usr/bin/env python
from setuptools import setup

with open('VERSION') as version_file:
    version = version_file.read().strip()

with open('downtoearth/version.py', 'w') as f:
    f.write("VERSION = '%s'\n" % version)

with open('README.rst') as readme_file:
    readme = readme_file.read()

install_requires = [
    'jinja2>=2.9.5'
]

setup(name='downtoearth',
      version=version,
      description='Utility to make API Gateway terraforms',
      long_description=readme,
      author='ClearDATA',
      url='https://github.com/cleardataeng/downtoearth',
      packages=['downtoearth'],
      scripts=['bin/downtoearth-cli.py'],
      package_data={'downtoearth': [
          'templates/*.hcl',
      ]},
      install_requires=install_requires,
      setup_requires=['pytest-runner',],
      tests_require=[
          'pytest',
      ],
      entry_points={
          'console_scripts': [
              'downtoearth = downtoearth.cli:main',
          ]
      },
     )
